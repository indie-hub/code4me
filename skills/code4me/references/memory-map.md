# Basic Memory Map

Use this reference when Basic Memory MCP tools are available.

## Startup Protocol

On orchestrator start, treat Basic Memory as an existing project knowledge base,
not as a blank code4me-owned store.

1. Detect whether Basic Memory tools are available in the MCP inventory.
2. Search for a project memory map/index note before other memory reads:
   - `code4me memory map`
   - `memory map`
   - `memory index`
   - `project conventions`
   - `decisions`
3. If a code4me memory map exists, read it and follow its category/tag rules.
4. If Basic Memory has notes but no code4me map, do not create competing
   structure automatically. Propose an adapter map that maps code4me categories
   to the project's existing tags/notes, then wait for user approval before
   writing it.
5. If Basic Memory appears empty, propose the default code4me map below and wait
   for user approval before writing it.

Never mass-retag, rename, or move existing Basic Memory notes. New durable
code4me notes should follow the approved map once it exists.

## Existing Structure Adapter

When memory already exists, propose a single note like:

```md
# code4me memory map

This project already had Basic Memory structure before code4me.

Existing structure:
- Decisions: <existing tag or note pattern>
- Bugs/incidents: <existing tag or note pattern>
- Preferences: <existing tag or note pattern>
- Conventions: <existing tag or note pattern>

code4me category mapping:
- insight -> <existing tag or note pattern>
- bug-pattern -> <existing tag or note pattern>
- dont-repeat -> <existing tag or note pattern>
- decision -> <existing tag or note pattern>
- preference -> <existing tag or note pattern>
- convention -> <existing tag or note pattern>
- integration -> <existing tag or note pattern>
- security -> <existing tag or note pattern>

Rules:
- Do not mass-retag old notes.
- New code4me notes should follow this map.
- Update this map only when adding a durable category/tag.
- Never store secrets, credentials, tokens, or private user data.
```

If search results are too sparse to infer a mapping, say so and offer the
default map as a starting point instead of pretending certainty.

## Default Map

For empty Basic Memory projects, propose one top-level note:

```md
# code4me memory map

Purpose: explain how this project uses Basic Memory with code4me.

Rules:
- Search this note first when using Basic Memory.
- Store durable project knowledge, not transient task logs.
- Prefer one atomic note per reusable lesson, decision, bug pattern, or
  preference.
- Update this map when adding a new durable tag/category.
- Never store secrets, credentials, tokens, or private user data.

Core tags:
- code4me
- insight
- bug-pattern
- dont-repeat
- decision
- preference
- convention
- integration
- security

Write guidance:
- recurring bug or failure mode -> `bug-pattern`
- user/project preference -> `preference`
- avoid repeating a mistake -> `dont-repeat`
- architecture/tooling choice -> `decision`
- reusable workflow lesson -> `insight`
- security-sensitive project rule -> `security`
```

Do not create empty bucket notes such as "bugs", "insights", or "dont-repeats"
up front. Tags plus atomic notes are enough. Add rollup notes later only when
there is real content to summarize.
