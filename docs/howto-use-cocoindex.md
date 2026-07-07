# How to use CocoIndex Code with code4me

CocoIndex Code provides AST-aware semantic code search. In code4me it sits next
to codegraph:

- codegraph: exact symbol graph questions
- CocoIndex Code: natural-language and fuzzy source discovery

## Install

Use one of the official install paths:

```bash
pipx install 'cocoindex-code[full]'
# or
uv tool install --upgrade 'cocoindex-code[full]'
```

The `[full]` extra includes local embeddings.

## Index a project

From the project root:

```bash
ccc index
ccc status
```

`ccc index` initializes the project if needed and creates `.cocoindex_code/`.

## Add MCP

For Codex CLI:

```bash
codex mcp add cocoindex-code -- ccc mcp
```

For Claude Code:

```bash
claude mcp add cocoindex-code -- ccc mcp
```

The MCP server exposes `search(query, limit, paths, languages)`.

## code4me behavior

`hooks/check-structural-first-on-source.sh` detects `ccc` or
`.cocoindex_code/` and asks agents to use CocoIndex before context-mode, `Read`,
or `Grep` for source-code discovery.

Run preflight to confirm:

```bash
bash <code4me-plugin>/bin/code4me-preflight
```

Official docs:

- https://cocoindex.io/cocoindex-code/
- https://github.com/cocoindex-io/cocoindex-code
