# How to use codegraph with code4me

codegraph is the preferred first tool for exact structural source-code questions:
definitions, callers, callees, impact, and nearby symbols.

## Install and index

Install codegraph, then initialize it at the project root:

```bash
npm i -g @colbymchenry/codegraph
cd <project>
codegraph init -i
```

The project is considered indexed when `.codegraph/codegraph.db` exists.

## Preferred use

Use codegraph before `Read`, `Grep`, or context-mode for graph-shaped questions:

- `codegraph_explore <symbol>` - definition, neighbors, call paths, blast radius
- `codegraph_callers <symbol>` - incoming calls
- `codegraph_callees <symbol>` - outgoing calls
- `codegraph_impact <symbol>` - downstream impact
- `codegraph_search <query>` - symbol search

Use CocoIndex Code for fuzzy or natural-language source discovery. Use LSP only
as a legacy optional fallback for type-precise language-server features.

## Runtime hook

`hooks/check-structural-first-on-source.sh` detects `.codegraph/codegraph.db` and
ask-gates common fallback shapes, including whole-file source `Read`, bare-symbol
`Grep`, and context-mode source searches. The event log is
`.code4me/structural-first-events.jsonl`.

The old `check-lsp-first-on-source.sh` path remains a compatibility wrapper.

## Verify

Run:

```bash
bash <code4me-plugin>/bin/code4me-preflight
```

Preflight reports whether `codegraph` is on PATH and whether the current project
has `.codegraph/codegraph.db`.
