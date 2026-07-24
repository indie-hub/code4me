# Code Consultation Precedence

When a subagent needs to understand existing source code, use code indexes before
text tools. The goal is simple: context-mode, `Read`, and `Grep` should not
overtake codegraph or CocoIndex for source-code lookup.

## Precedence

### 1. codegraph

Use codegraph first for exact graph-shaped questions when
`.codegraph/codegraph.db` exists:

- `codegraph_explore <symbol>` for definition, neighbors, call paths, and blast
  radius
- `codegraph_callers <symbol>` for incoming calls
- `codegraph_callees <symbol>` for outgoing calls
- `codegraph_impact <symbol>` for downstream impact
- `codegraph_search <query>` for symbol search

### 2. CocoIndex Code

Use CocoIndex Code first for semantic or fuzzy code discovery:

- MCP `search(query, limit, paths, languages)`
- CLI `ccc search "<natural language query>"`
- CLI `ccc index` once when the repo has not been indexed

CocoIndex is best when you know the behavior you want but not the exact symbol
name. It is also the preferred first step for broad "find the area of the
codebase that handles X" questions.

### 3. LSP

LSP is legacy optional. Use it when `.lsp.json` exists and the question needs
language-server precision: hover types, diagnostics, implementations, or exact
single-language references.

### 4. `Read`

Use `Read` after an index has narrowed the target to a file and region. Whole-file
reads are acceptable for small files or when the user explicitly asks to inspect
the entire file, but they should not be the first move for symbol lookup.

### 5. context-mode

Use context-mode for derived analysis after the relevant code area is known, or
for non-source material such as logs, build output, generated reports, markdown,
and large config files.

Examples:

- count patterns in a known file
- summarize a long test log
- aggregate JSONL dispatch data
- process docs without loading raw bytes into the thread

Do not use context-mode as the first step for source questions such as "where is
X defined?" or "who calls Y?" when codegraph or CocoIndex can answer.

### 6. Grep/Glob

Use text search for genuinely text-shaped queries:

- regex inside comments or string literals
- generated artifacts not indexed by code tools
- non-source config and markdown
- exact text that is not a symbol or behavior query

## Runtime Hook

`hooks/check-structural-first-on-source.sh` nudges common source-consultation
fallback shapes when a structural code surface is present:

- whole-file `Read` of a source file
- bare-identifier `Grep` against source files
- context-mode `ctx_execute` / `ctx_batch_execute` running grep-like commands
  against source files
- `ctx_execute_file` on a source file with symbol-search verbs
- raw `cat`/`head`/`tail`/`sed` reads paired with function/class/method queries

The old `check-lsp-first-on-source.sh` path remains as a compatibility wrapper
for projects that already have it in `.claude/settings.json`.

## Proceed Cases

When the query is intentionally text-shaped or an index cannot answer it,
continue normally after considering the non-blocking guidance:

- regex in comments or strings
- generated files or build outputs
- a small file where whole-file read is cheaper than tool setup
- a whole-file read after a code index already found the relevant file
- analysis work that requires running code over file contents

Record a brief reason in the thread when proceeding so audit logs can distinguish
intentional fallback from tool-order drift.
