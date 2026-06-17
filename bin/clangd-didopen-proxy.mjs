#!/usr/bin/env node
// clangd-didopen-proxy.mjs
//
// Workaround for Claude Code CLI bug (anthropics/claude-code#29501) where
// AST-requiring LSP requests are dispatched to clangd without a prior
// textDocument/didOpen, so clangd rejects them with
// "trying to get AST for non-added document".
//
// This proxy sits between the harness and clangd on stdio. For each
// AST-requiring request it observes, if the target URI has not yet been
// opened, it reads the file off disk, synthesises a didOpen notification,
// and then forwards the original request. All other LSP traffic is passed
// through verbatim (no re-serialisation).
//
// Wire-up in .lsp.json (replace the "cpp" entry's command/args):
//   "command": "node",
//   "args": [
//     "<absolute path to this file>",
//     "--background-index",
//     "--clang-tidy"
//   ]
//
// Override the spawned clangd binary with CLANGD_REAL_PATH if needed.

import { spawn } from 'node:child_process';
import { readFileSync } from 'node:fs';

const REAL_CLANGD = process.env.CLANGD_REAL_PATH || 'clangd';

const clangd = spawn(REAL_CLANGD, process.argv.slice(2), {
	stdio: ['pipe', 'pipe', 'inherit'],
	windowsHide: true,
});

clangd.on('error', (err) => {
	process.stderr.write(`[clangd-didopen-proxy] failed to spawn '${REAL_CLANGD}': ${err.message}\n`);
	process.exit(1);
});
clangd.on('exit', (code) => process.exit(code ?? 0));

// AST-requiring methods. documentSymbol omitted: clangd serves it from the
// static index without needing didOpen, so injecting one would just add
// pointless parse cost.
const AST_METHODS = new Set([
	'textDocument/hover',
	'textDocument/references',
	'textDocument/definition',
	'textDocument/declaration',
	'textDocument/implementation',
	'textDocument/typeDefinition',
	'textDocument/documentHighlight',
	'textDocument/signatureHelp',
	'textDocument/completion',
	'textDocument/codeAction',
	'textDocument/codeLens',
	'textDocument/formatting',
	'textDocument/rangeFormatting',
	'textDocument/rename',
	'textDocument/prepareCallHierarchy',
	'textDocument/prepareTypeHierarchy',
	'textDocument/foldingRange',
	'textDocument/selectionRange',
	'textDocument/semanticTokens/full',
	'textDocument/semanticTokens/range',
]);

const opened = new Set();

function uriToPath(uri) {
	if (typeof uri !== 'string' || !uri.startsWith('file://')) return null;
	let p = uri.slice('file://'.length);
	// Strip leading slash on Windows drive paths: file:///C:/foo -> C:/foo
	if (/^\/[A-Za-z]:[/\\]/.test(p)) p = p.slice(1);
	try { p = decodeURIComponent(p); } catch { /* leave as-is */ }
	return p;
}

function languageIdForUri(uri) {
	const lower = uri.toLowerCase();
	if (lower.endsWith('.c')) return 'c';
	if (lower.endsWith('.m')) return 'objective-c';
	if (lower.endsWith('.mm')) return 'objective-cpp';
	return 'cpp';
}

function frame(json) {
	const body = JSON.stringify(json);
	const len = Buffer.byteLength(body, 'utf8');
	return `Content-Length: ${len}\r\n\r\n${body}`;
}

function readWithoutBOM(path) {
	const text = readFileSync(path, 'utf8');
	return text.charCodeAt(0) === 0xFEFF ? text.slice(1) : text;
}

function ensureOpened(uri) {
	if (!uri || opened.has(uri)) return;
	const path = uriToPath(uri);
	if (!path) return;
	let text;
	try {
		text = readWithoutBOM(path);
	} catch {
		return; // file unreadable; let the original request fail downstream
	}
	opened.add(uri);
	clangd.stdin.write(frame({
		jsonrpc: '2.0',
		method: 'textDocument/didOpen',
		params: {
			textDocument: {
				uri,
				languageId: languageIdForUri(uri),
				version: 1,
				text,
			},
		},
	}));
}

// LSP frame parser that forwards verbatim bytes to `dest`, calling
// `onMessage` once per fully-parsed JSON frame, before forwarding it.
function makeForwarder(dest, onMessage) {
	let buf = Buffer.alloc(0);
	return (chunk) => {
		buf = Buffer.concat([buf, chunk]);
		while (true) {
			const sep = buf.indexOf('\r\n\r\n');
			if (sep === -1) return;
			const header = buf.slice(0, sep).toString('ascii');
			const m = header.match(/Content-Length:\s*(\d+)/i);
			if (!m) {
				dest.write(buf.slice(0, sep + 4));
				buf = buf.slice(sep + 4);
				continue;
			}
			const len = parseInt(m[1], 10);
			const start = sep + 4;
			if (buf.length < start + len) return;
			const fullFrame = buf.slice(0, start + len);
			const body = buf.slice(start, start + len).toString('utf8');
			buf = buf.slice(start + len);
			let msg = null;
			try { msg = JSON.parse(body); } catch { /* malformed; still forward */ }
			if (msg) onMessage(msg);
			dest.write(fullFrame);
		}
	};
}

// harness -> clangd
const fromHarness = makeForwarder(clangd.stdin, (msg) => {
	if (msg.method === 'textDocument/didOpen') {
		const uri = msg.params?.textDocument?.uri;
		if (uri) opened.add(uri);
		return;
	}
	if (msg.method === 'textDocument/didClose') {
		const uri = msg.params?.textDocument?.uri;
		if (uri) opened.delete(uri);
		return;
	}
	if (msg.method && AST_METHODS.has(msg.method)) {
		ensureOpened(msg.params?.textDocument?.uri);
	}
});
process.stdin.on('data', fromHarness);
process.stdin.on('end', () => clangd.stdin.end());

// clangd -> harness: byte-for-byte forward, no inspection needed.
clangd.stdout.on('data', (chunk) => process.stdout.write(chunk));
