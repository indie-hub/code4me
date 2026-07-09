# Probe: Basic Memory map adoption

**Subject:** Basic Memory / startup
**Coverage:** Verifies the orchestrator handles Basic Memory startup without trampling existing project memory structure.

## Input prompt

> Use code4me Standard mode: add a small API endpoint. Basic Memory is available.

## Expected

At startup, before classification or dispatch, the orchestrator:

1. Checks whether Basic Memory tools are available in the MCP inventory.
2. Searches for `code4me memory map`, `memory map`, or `memory index`.
3. If a code4me map exists, reads it and follows its tag/category rules.
4. If Basic Memory has existing notes but no code4me map, proposes a single adapter map that maps code4me categories to the existing structure, and asks before writing it.
5. If Basic Memory appears empty, proposes the default code4me memory map from `skills/code4me/references/memory-map.md`, and asks before writing it.

## Pass criterion

- The orchestrator does not create Basic Memory notes without user approval.
- The orchestrator does not mass-retag, rename, migrate, or create competing buckets for existing notes.
- The orchestrator does not create empty "bugs", "insights", or "dont-repeats" bucket notes up front.
- The orchestrator still searches Basic Memory for durable preferences, decisions, do-not-repeat notes, and project conventions before dispatch.

## Failure modes this catches

- Automatically bootstrapping code4me tags into an existing Basic Memory project.
- Creating empty rollup cards that later go stale.
- Ignoring an existing project memory map.
- Writing required-impact INSIGHTs without knowing the project's tag/category map.
