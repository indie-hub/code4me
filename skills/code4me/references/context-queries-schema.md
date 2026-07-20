# Context Queries Schema

`context_queries:` frontmatter lets each agent declare what the orchestrator
should include in its Context Pack at dispatch time. Universal items such as task
ID, model, vendor, completion expectations, and the transparency announcement are
still appended by the orchestrator.

## Shape

```yaml
context_queries:
  - kind: <query-kind>
    # kind-specific fields
```

The block lives in agent YAML frontmatter after `description:`.

## Supported Kinds

### `artifact`

Retrieve local workflow artifacts from `.code4me/`.

```yaml
- kind: artifact
  type: tech-spec | test-spec | milestone-spec | conversation-note | insight-register | execution-dependency-plan | architecture-discussion-record
  filter: milestone={milestone_id}
  relevance: this-role | this-milestone | all | prior-revision | prior-rounds | recent
  limit: 3
  required: false
  when: "weight in [Standard, Critical]"
```

### `basic-memory`

Query Basic Memory when its MCP tools are available.

```yaml
- kind: basic-memory
  query: "architecture conventions for {module}"
  purpose: decision-history | prior-fixes | user-preferences | project-conventions
  limit: 5
  required: false
```

If Basic Memory is not configured, optional queries are skipped and named in the
transparency announcement. Required memory queries should block with
`blocker_type: memory_unavailable`.

### `protected-list`

Reference a list written by another subagent.

```yaml
- kind: protected-list
  file: .code4me/protected-tests.txt
  required-for: [Critical]
```

### `forbidden-conditions`

Reference Conversation Mode forbidden conditions.

```yaml
- kind: forbidden-conditions
  file: .code4me/forbidden-conditions.json
  applies-when: "weight == Conversation"
```

### `project-info`

Gather static project facts or user-declared project guidance.

```yaml
- kind: project-info
  type: claude-md | language-guidance | mcp-inventory | dependency-manifest | ci-config | diff-range
  detail: per-file-extension | full | ci-and-coverage | runtime-monitoring-logs | web-search-and-doc-indexes
  relevance: project-root | per-task-files | security-relevant | test-infrastructure
```

### `dispatch-reminder`

Emit a stock reminder line into the Context Pack.

```yaml
- kind: dispatch-reminder
  content: tooling-hierarchy | language-injection | model-explicit | code-consultation-precedence
```

Agents that consult source code should declare
`content: code-consultation-precedence` so the dispatch reminds them that
codegraph and CocoIndex precede context-mode, `Read`, and `Grep` for source-code
lookup.

## `when:` DSL

The `when:` value is a quoted string.

Examples:

```yaml
when: "weight in [Standard, Critical]"
when: "mode == review-diff"
when: "vendor_pairing.enabled == true"
```

Use separate queries for alternatives. The DSL is intentionally small and
mode-aware.

## Resolution

At dispatch time, the orchestrator:

1. Reads the dispatched agent's `context_queries:` block.
2. Evaluates `when:` conditions and skips false queries.
3. Resolves remaining queries in order.
4. Records provenance for every resolved or skipped query.
5. Assembles the Context Pack.
6. Appends universal items.
7. Dispatches.

Resolution behavior:

- `artifact`: locate matching `.code4me/` artifact; required missing artifacts
  block with `blocker_type: missing_artifact`.
- `basic-memory`: query Basic Memory MCP tools; optional unavailable memory is
  skipped, required unavailable memory blocks with `memory_unavailable`.
- `protected-list` and `forbidden-conditions`: include file path and small
  contents when present.
- `project-info`: gather from project structure, `AGENTS.md`/`CLAUDE.md`, manifests, and MCP
  inventory.
- `dispatch-reminder`: emit stock reminder text.

## Provenance

Every dispatch-log line records `context_provenance` entries:

```json
{
  "query_kind": "artifact",
  "query_descriptor": "tech-spec milestone=M07",
  "resolved_artifact": ".code4me/tech-specs/M07.md",
  "resolved_sha": "<git SHA or null>",
  "size_bytes": 1234,
  "truncated": false,
  "skipped": false,
  "skip_reason": null
}
```

Skipped optional queries also get provenance with `skipped: true` and a concise
`skip_reason`. This makes Context Pack assembly auditable without requiring the
user to reconstruct what was available during dispatch.
