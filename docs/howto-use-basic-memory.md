# How To Use Basic Memory With code4me

Basic Memory means `basicmachines-co/basic-memory`. Use it for durable project
knowledge: decisions, user preferences, recurring fixes, and lessons that
should survive across sessions and tools.

Local workflow artifacts remain under `.code4me/`; Basic Memory is the
cross-session knowledge layer.

## Codex CLI Local MCP

```bash
codex mcp add basic-memory bash -c "uvx basic-memory mcp"
codex mcp list
```

To pin a Basic Memory project:

```bash
codex mcp add basic-memory bash -c "uvx basic-memory mcp --project your-project-name"
```

## Codex App Local MCP

The Codex app talks to MCP over HTTP. Start a local server:

```bash
basic-memory mcp --transport streamable-http --port 8000
# or
uvx basic-memory mcp --transport streamable-http --port 8000
```

Then add `http://localhost:8000/mcp` in Codex connector settings.

## Basic Memory Cloud

For Codex CLI, configure a remote MCP endpoint:

```toml
[mcp_servers.basic-memory]
url = "https://cloud.basicmemory.com/mcp"
bearer_token_env_var = "BASIC_MEMORY_API_KEY"
```

Export `BASIC_MEMORY_API_KEY` in the shell that launches Codex.

## code4me Behavior

When Basic Memory tools are available, the orchestrator should:

- search for `code4me memory map`, `memory map`, or `memory index` first
- follow an existing map when found
- propose an adapter map when the project already has Basic Memory notes but no code4me map
- propose the default code4me map when Basic Memory appears empty
- use `search` or `search_notes` before classification and architecture decisions
- use `build_context` for `memory://` URLs returned by search
- use `write_note` or `edit_note` for required-impact INSIGHTs
- include relevant prior decisions and recurring fixes in Context Packs
- persist required-impact INSIGHTs as durable notes

The orchestrator must ask before writing a new map. It should not mass-retag,
rename, or migrate existing notes. See `skills/code4me/references/memory-map.md`
for the default map and adapter template.

Official docs:

- https://docs.basicmemory.com/integrations/codex/
- https://docs.basicmemory.com/
