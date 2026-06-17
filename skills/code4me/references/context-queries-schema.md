# Context Queries Schema

This document defines the `context_queries:` frontmatter block that each agent file declares to specify what the orchestrator should include in its Context Pack at dispatch time.

## Purpose

Before v0.6, the orchestrator built Context Packs imperatively — `references/playbook.md` prose listed *"every dispatch must include task ID, spec, modules, model parameter, MCP inventory, language guidance, tooling reminder."* Same shape every time, regardless of which subagent was being invoked.

Declarative `context_queries` moves this to per-agent frontmatter. Each agent declares what *it* needs; the orchestrator resolves the queries and assembles the Context Pack from the results. Universal items (task ID, model parameter, transparency announcement) are still appended by the orchestrator after resolution.

This change is **specification only** in v0.6 — the orchestrator resolves queries by reading agent frontmatter and using its own judgment to fetch artifacts. v0.7 may add deterministic resolver scripts in `bin/` for repeatability and audit.

## Schema

```yaml
context_queries:
  - kind: <query-kind>
    # kind-specific fields
```

The block lives inside the agent's YAML frontmatter, after `description:` and before any `<example>` blocks.

### Supported kinds

#### `artifact`

Retrieve an artifact from `.code4me/`.

```yaml
- kind: artifact
  type: tech-spec | test-spec | milestone-spec | conversation-note | insight-register | execution-dependency-plan | architecture-discussion-record
  filter: <key=value pairs>           # e.g., milestone={milestone_id}, task={task_id}
  relevance: this-role | this-milestone | all | prior-revision | prior-rounds | recent
  limit: <int>                        # optional
  required: <bool>                    # optional; default false
  when: "<condition>"                 # optional; quoted DSL, see "Mode and weight conditions" below
```

#### `openwolf`

Read OpenWolf state when configured (`.wolf/` at project root).

```yaml
- kind: openwolf
  file: cerebrum | anatomy | buglog
  sections: [<list of section names>]   # optional; cerebrum-specific
  relevance: full-project | modules-in-scope | surface | security-related | research-question | prior-critiques | test-infrastructure
  limit: <int>                          # optional
```

If `.wolf/` does not exist, the query is silently skipped (and noted in the transparency announcement).

#### `protected-list`

Reference a list file written by another subagent (typically Spec-to-Test).

```yaml
- kind: protected-list
  file: .code4me/protected-tests.txt
  required-for: [<list of modes or weights>]   # optional
```

#### `forbidden-conditions`

Reference the forbidden-conditions JSON managed by the orchestrator at Conversation Mode dispatch.

```yaml
- kind: forbidden-conditions
  file: .code4me/forbidden-conditions.json
  applies-when: "<condition>"
```

#### `project-info`

Static project facts the orchestrator gathers (or that the user has declared in `CLAUDE.md`).

```yaml
- kind: project-info
  type: claude-md | language-guidance | mcp-inventory | dependency-manifest | ci-config | diff-range
  detail: per-file-extension | full | ci-and-coverage | runtime-monitoring-logs | web-search-and-doc-indexes
  relevance: project-root | per-task-files | security-relevant | test-infrastructure
  when: "<condition>"                   # optional
```

#### `dispatch-reminder`

A short universal reminder the orchestrator emits into every Context Pack.

```yaml
- kind: dispatch-reminder
  content: tooling-hierarchy | language-injection | model-explicit | code-consultation-precedence
```

Most agents declare at least `kind: dispatch-reminder, content: tooling-hierarchy` to acknowledge the universal tooling reminder applies. The orchestrator may emit the reminder regardless — declaring it makes the dependency explicit for audit.

Subagents that consult existing source code (developer, code-reviewer, verification) also declare `content: code-consultation-precedence` to surface the LSP-first ordering at dispatch time (v0.10.5+). The orchestrator emits a one-line pointer to `references/code-consultation-precedence.md`; the runtime hook `check-lsp-first-on-source.sh` ask-gates symbol-shaped `ctx_execute` calls against languages declared in `.lsp.json`.

## Mode and weight conditions

For Codex shim agents (mode-aware) and weight-conditional queries, the `when:` field uses a tiny string DSL evaluated by the orchestrator:

- `"mode = challenge"`
- `"mode in [challenge, review-spec]"`
- `"weight = Conversation"`
- `"weight in [Standard, Critical]"`

Multi-clause conditions use comma to mean AND: `"mode = implement, weight in [Standard, Critical]"`. There is no OR — express alternatives via separate queries.

The `when:` value is always a quoted string in the YAML so the YAML parser doesn't try to interpret `[...]` as a flow-style list.

## Resolution at dispatch

At dispatch time, the orchestrator:

1. Reads the dispatched agent's `context_queries:` block.
2. For each query, evaluates `when:` if present; skips the query if the condition is false.
3. Resolves each remaining query in order:
   - `artifact`: locate the file matching `type` and `filter`; if `required: true` and missing, return `BLOCKED` with `blocker_type: missing_artifact` to the user.
   - `openwolf`: if `.wolf/` is configured, read the named file (optionally filtered by `sections` or `relevance`); otherwise note skip.
   - `protected-list`, `forbidden-conditions`: check the file exists; include its path and (if small) its contents in the Context Pack.
   - `project-info`: gather the indicated info from project structure or `CLAUDE.md`.
   - `dispatch-reminder`: emit the stock reminder line.
4. **Record provenance** for every resolved query (see "Resolution provenance" below).
5. Assemble the Context Pack from resolved results.
6. Append universal items: task ID, parent milestone, vendor, model_tier, model, completion expectations, vendor_pairing block, transparency announcement.
7. Dispatch.

Unresolved optional queries are noted in the dispatch transparency announcement (`Context queries skipped: <list with reasons>`) so the audit trail records what was *not* available.

## Resolution provenance (v0.8+)

For each successfully resolved query, the orchestrator records a `context_provenance` entry in the dispatch-log JSONL line. The field is an array of objects, one per resolved query, capturing **what** answered the query and (where applicable) **at what version**. This lets the audit tool answer "when this dispatch went wrong, what context was in the pack?" without re-running the workflow.

### Provenance entry shape

```json
{
  "query_kind": "artifact" | "openwolf" | "protected-list" | "forbidden-conditions" | "project-info" | "dispatch-reminder",
  "query_descriptor": "<type or file or content key from the query>",
  "resolved_artifact": "<path or null if no concrete file>",
  "resolved_sha": "<git SHA of the file at dispatch time, or null if not in git>",
  "size_bytes": <int, optional — for items included verbatim in the Context Pack>,
  "truncated": <bool, optional — true if the orchestrator clipped large content to fit budget>,
  "skipped": <bool — true if the query evaluated but resolved to no content (e.g., OpenWolf not configured)>,
  "skip_reason": "<one-line, only when skipped: true>"
}
```

### Examples

A dispatch with three resolved queries — a Tech Spec, an OpenWolf cerebrum section, and an injected language guidance file — produces:

```json
"context_provenance": [
  {
    "query_kind": "artifact",
    "query_descriptor": "tech-spec milestone=M07",
    "resolved_artifact": ".code4me/tech-specs/M07-spec.md",
    "resolved_sha": "a3f2b91c8d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8",
    "size_bytes": 4231,
    "truncated": false,
    "skipped": false
  },
  {
    "query_kind": "openwolf",
    "query_descriptor": "cerebrum sections=[coding-conventions]",
    "resolved_artifact": ".wolf/cerebrum.md",
    "resolved_sha": "9c8b7a6d5e4f3a2b1c0d9e8f7a6b5c4d3e2f1a0",
    "size_bytes": 612,
    "truncated": false,
    "skipped": false
  },
  {
    "query_kind": "project-info",
    "query_descriptor": "language-guidance per-file-extension (.go)",
    "resolved_artifact": "skills/code4me/references/languages/go.md",
    "resolved_sha": null,
    "size_bytes": 1834,
    "truncated": false,
    "skipped": false
  }
]
```

A dispatch where OpenWolf is not configured records the skip explicitly:

```json
{
  "query_kind": "openwolf",
  "query_descriptor": "cerebrum sections=[architecture-conventions]",
  "resolved_artifact": null,
  "resolved_sha": null,
  "skipped": true,
  "skip_reason": "OpenWolf not configured (.wolf/ does not exist)"
}
```

### SHA recording

When the resolved artifact is tracked in git, `resolved_sha` is the file's blob SHA at the time of dispatch (`git hash-object <path>` semantics — the content hash, not the commit SHA). This is intentional: the content is what fed the dispatch; the commit history is incidental.

When the artifact is plugin-shipped (under the plugin's checkout, not the project's git tree) or generated, `resolved_sha` is `null`. The `resolved_artifact` path is sufficient because plugin content versions through `plugin.json`'s `version` field.

When the artifact lives on disk but isn't in any git tree (e.g., a `.code4me/` artifact in a project that hasn't been committed yet), `resolved_sha` is `null` and the orchestrator notes this in the transparency announcement.

### Why provenance matters

Three diagnostic uses:

1. **Post-mortem on a wrong dispatch.** "Why did the Developer not see the latest Tech Spec amendment?" — the dispatch log answers it: provenance shows the SHA at dispatch time; you can diff against the current SHA and see whether the orchestrator picked up a stale revision or whether the developer ignored the up-to-date one.
2. **Audit of Context Pack assembly correctness.** "Did every dispatch for this Critical milestone include the security-conventions cerebrum section?" — provenance makes this a one-line `jq` query against the dispatch log.
3. **Token-budget tuning.** `size_bytes` and `truncated` surface where the orchestrator is clipping content. Persistent truncation of a specific query type is signal that the agent's `context_queries` block is over-asking or the underlying artifact is bloated.

The audit tool (`bin/code4me-audit-dispatch-log` from v0.8+) reads `context_provenance` when present and surfaces a "Context provenance summary" section listing resolved-artifact counts by query kind plus any persistent truncation patterns.

### Backward compatibility

Dispatches written by v0.7 and earlier orchestrators do not carry `context_provenance`. The audit tool treats missing provenance as "pre-v0.8 dispatch" and notes it in the summary; existing log lines remain valid.

## Backward compatibility

In v0.6, an agent that does not declare `context_queries:` continues to work — the orchestrator falls back to the imperative Context Pack list in `references/playbook.md`. This lets the schema be adopted incrementally without breaking unaware agents.

By v0.7 the fallback path is expected to be deprecated; all shipped agents will declare context_queries explicitly. Custom agents the user adds outside the plugin distribution can adopt the schema at their own pace.

## What this does *not* solve

- **Dynamic artifact filtering.** `filter: milestone={milestone_id}` uses template substitution at dispatch — `{milestone_id}` is replaced with the active milestone. More complex filtering (regex on artifact contents, time windows) is out of scope for v0.6.
- **Deterministic resolution.** v0.6 has the orchestrator resolve queries via its own reasoning. v0.7 plan: small shell or python resolvers in `bin/` so the same query produces the same Context Pack regardless of which orchestrator instance runs.
- **Cross-agent query merging.** Each agent's queries are resolved independently. If two agents in the same dispatch sequence declare overlapping queries (e.g., both want `tech-spec`), the resolution happens twice. Cheap given current artifact sizes; revisit if it bites.
