# Code Consultation Precedence (v0.10.5+, structural-first as of v0.13)

When a subagent needs to understand existing code — "where is X defined?", "what calls Y?", "what does this file do?", "what's wrong with this region?" — it has several surfaces available: **codegraph** (when indexed), **LSP** (when wired), the normal `Read` tool, context-mode's `ctx_execute_file` / `ctx_execute` / `ctx_search`, and plain `Grep`. They aren't interchangeable. This document specifies the order in which to reach for them, and the patterns the runtime hook (`check-lsp-first-on-source.sh`) will ask-gate to enforce the order.

## Why this matters

Without an explicit precedence, the cheap default is "use the most familiar tool" — and the most familiar tool for symbol queries tends to be `ctx_execute` with a `grep` or `ctx_execute_file` with a "find functions" script, because the output is text and text is what the model is most comfortable working with. The cost: a 50-line grep instead of a one-line structural response, with the structural information (parameter types, return types, call chains) discarded. Multiplied across a Standard or Critical dispatch, this is several thousand tokens of avoidable noise per subagent.

**Structural tools give the answer in one call, with rich context, language-aware or graph-aware.** They're specifically built for these queries. Reaching for `grep` when a structural tool is available is a regression to a pre-LSP workflow.

## Two structural tools, both valid

As of v0.13, code4me recognizes **two structural alternatives** to grep/Read for code consultation. They're complementary, not redundant — pick whichever fits the question better:

- **codegraph** (when `.codegraph/codegraph.db` exists at project root). Graph-shaped, pre-indexed via tree-sitter + SQLite. Best for cross-file structural questions: "who calls X across the whole repo?", "if I change X what breaks?", "tell me about X including its neighbors and cross-language edges." Returns rich text in one call. Independent of language servers; works for any indexed language.
- **LSP** (when `.lsp.json` declares the file's extension). Language-aware, type-precise, per-server. Best for type signatures, refactoring-grade reference accuracy, and language-specific diagnostics: "what type is X?", "what's wrong with this file?", "what implementations does X have?".

The hook ask-gates symbol-shaped queries on source files regardless of whether one or both structural tools are present, surfacing whichever is available in the redirect message. **An agent should reach for codegraph or LSP first, then fall back to Read/Grep only when neither can answer the specific question.**

## The precedence

Use in this order for **source-code consultation queries**. The hook will ask-gate downstream tools when an upstream tool would have answered.

### 1. codegraph or LSP (first, when either is available)

When the question is about a symbol, a relationship between symbols, or a cross-reference graph: reach for codegraph or LSP first.

**codegraph** (preferred for cross-file / graph-shaped questions):

- **"Tell me about X — its definition, neighbors, and cross-language edges"** → `codegraph_explore <symbol>`
- **"Who calls X across the whole repo?"** → `codegraph_callers <symbol>`
- **"What does X call (transitively)?"** → `codegraph_callees <symbol>`
- **"If I change X, what's downstream impact?"** → `codegraph_impact <symbol>`
- **"Find a symbol by approximate name"** → `codegraph_search <query>` (FTS5)

**LSP** (preferred for type-precise / language-specific questions, when `.lsp.json` covers the file's extension):

- **"Where is X defined?"** → `textDocument/definition`
- **"Who calls X / where is X used?"** → `textDocument/references`
- **"What type is X / what's X's signature?"** → `textDocument/hover`
- **"What symbols are in this file?"** → `textDocument/documentSymbol`
- **"Find a symbol by name across the workspace"** → `workspace/symbol`
- **"What does X implement / what implementations does X have?"** → `textDocument/implementation` (where supported)
- **"What's wrong with this file?"** → `textDocument/diagnostics` (or `publishDiagnostics`)
- **"What types/methods are available on this expression?"** → `textDocument/completion` (rarely needed in code consultation but available)
- **"What is the call hierarchy of X?"** → `callHierarchy/incomingCalls` / `outgoingCalls`

Both codegraph and LSP responses are token-cheap and structurally rich. When either can answer, it should be the first call.

**Which to pick when both are available:** codegraph's strengths are cross-file graph traversal (impact, callers across the repo, cross-language edges) and the rich, one-call response shape. LSP's strengths are type precision (hover for full type signatures), language-specific diagnostics, and refactoring-grade reference accuracy within one language. For exploration ("how does this auth system work?") reach for codegraph first; for type questions ("what's the exact signature of `Verify`?") reach for LSP first. When in doubt, codegraph's response is usually faster to digest because it's one call returning rich text.

### 2. `Read` (for "show me this whole file / region" *after* a structural tool has narrowed it down)

Once codegraph or LSP gives you a file path + line range, use `Read` (with `offset` and `limit`) to fetch the exact span. This is the second-best shape for code consultation: precise, no overhead, no analysis-language interpretation layer.

Examples:

- LSP definition returns `src/auth/PasswordReset.cs#L42-L78` → `Read(file_path: ".../PasswordReset.cs", offset: 42, limit: 37)`
- `codegraph_explore PasswordResetService` returns location → `Read` the file with a relevant range when you need to see implementation, not just signatures.
- LSP documentSymbol returns the list of methods in a file → `Read` the file with a relevant range when you need to see implementation, not just signatures.

### 3. `ctx_execute_file` (for whole-module analysis after symbol triage)

`ctx_execute_file` shines when:

- You need to run **analysis code** over a file (count occurrences, extract metrics, derive a structured summary). The file loads into `FILE_CONTENT` server-side, so the file's text never enters the consultation thread's context.
- The query is **non-symbolic** — "how many TODOs in this file?", "what are the public types and their line counts?", "what's the average function length?"
- LSP's answer is incomplete and you need to scan a region for patterns LSP doesn't surface (specific comment patterns, embedded TODO markers, custom annotations).

It is **not** the right tool for "find function FooBar" or "where is class Baz declared". Those are codegraph or LSP queries. The runtime hook will ask-gate `ctx_execute_file` invocations whose `path` is a source file (per `.lsp.json`) and whose `code` contains symbol-search verbs (`find function`, `where is`, `definition of`, `references to`, etc.).

### 4. `ctx_search` (for non-source surfaces: indexed docs, build outputs, log files)

`ctx_search` is right when the target was previously indexed (`ctx_fetch_and_index` for external docs, `ctx_index` for local files explicitly added to the knowledge base). It's not the right tool for source-code consultation unless the source was indexed deliberately as text (e.g., reading through generated documentation, not querying the AST).

### 5. `ctx_execute` with `grep` / `rg` / `ag` / `ack` (last resort, only for genuine text searches)

`ctx_execute` with a grep family tool is appropriate when:

- The search is **across non-source files** (config, markdown, CSV, build artifacts).
- The search is **regex against comments or strings** where neither codegraph nor LSP can help (because the regex matches inside string literals or comment bodies — neither indexes arbitrary text content).
- The target file's language **is not declared in `.lsp.json`** AND codegraph hasn't indexed it (the hook auto-no-ops on no-`.lsp.json` projects anyway).

The hook will ask-gate `grep|rg|ag|ack` invocations against files whose extension appears in `.lsp.json`, on the assumption that those queries are symbol-shaped. Type `yes` at the ask-prompt if the search is genuinely text-shaped and neither structural tool can help.

## The hook's pattern surface

`check-lsp-first-on-source.sh` matches **five** shapes across five tools (v0.11+). The first two cover the built-in tools agents reach for most often; the last three cover context-mode's family. Subagents should know what these look like so they can anticipate the ask-gate and reach for LSP directly.

| Shape | Example that ask-gates | What to use instead |
|---|---|---|
| **Whole-file `Read` of a source file (no offset+limit)** | `Read(file_path: "src/auth/PasswordReset.cs")` | `codegraph_explore PasswordReset` (rich one-call response) OR `textDocument/documentSymbol` first to locate the relevant region, then `Read(file_path, offset, limit)` for the specific span |
| **`Grep` with a bare-identifier pattern against source files** | `Grep(pattern: "PasswordResetService", type: "cs")` | `codegraph_explore PasswordResetService` OR `workspace/symbol("PasswordResetService")` — returns the symbol's location structurally |
| **`grep`/`rg`/`ag`/`ack` inside `ctx_execute` against `.cs`/`.swift`/`.cpp`/`.h`/etc.** | `ctx_execute(code: "rg PasswordResetService src/")` | `codegraph_callers PasswordResetService` (for caller graphs) OR `workspace/symbol("PasswordResetService")` |
| **`ctx_execute_file` on source + symbol-search verb in the code** | `ctx_execute_file(path: "src/foo.cs", code: "find all functions and list them")` | `codegraph_explore src/foo.cs` OR `textDocument/documentSymbol` on the file |
| **`cat`/`head`/`tail`/`sed -n` of source + function/class regex** | `ctx_execute(code: "cat src/foo.cs \| grep 'class '")` | `codegraph_explore` for the relevant symbol OR `textDocument/documentSymbol`, then `Read` the relevant range |

The hook checks each shape independently and ask-gates with the same message: a list of structural capabilities to consider first (codegraph when indexed, LSP always), with the option to type "yes" if the agent has reason to.

### Read's offset+limit carve-out

The Read gate is specifically narrowed by the offset+limit fields. The reasoning: a Read **without** an explicit range is "show me the whole file because I don't know what region I want yet" — which is the exact moment LSP would help locate the right region structurally. A Read **with** offset+limit means the agent has already narrowed the question (often from a prior LSP call, sometimes from Grep results, occasionally from a path the user named directly), and the gate stays quiet.

Practical workflow:

```
1. workspace/symbol("PasswordResetService")
   → returns { file: "src/auth/PasswordReset.cs", line: 42 }

2. Read(file_path: "src/auth/PasswordReset.cs", offset: 35, limit: 50)
   → returns just the relevant ~50 lines around the symbol
   → gate doesn't fire (offset+limit set)
```

vs. the gated path:

```
1. Read(file_path: "src/auth/PasswordReset.cs")     ← ask-gate fires
   → "did you query LSP first? workspace/symbol or documentSymbol would
      tell you where the relevant region is — then Read with offset+limit"
```

### Grep's bare-identifier carve-out

The Grep gate fires only when the pattern looks like a bare identifier (`^[a-zA-Z_][a-zA-Z0-9_]{2,}$` after stripping word-boundary markers like `\b`, `^`, `$`). This is the shape of "search for a symbol by name" — exactly what LSP's `workspace/symbol` or `textDocument/references` answers structurally.

Grep patterns that are genuine regex (contain `.*`, `[...]`, `|`, `(...)`, etc.) pass through unchanged. So do patterns shorter than 3 characters (too short to be meaningful symbol names; usually 2-char patterns are intentional substring searches, e.g., matching abbreviations or single-character flags). Comment-content searches and string-literal searches that happen to look like identifiers will still trigger the gate — proceed with "yes" if that's genuinely what you're doing.

The target check uses four signals, in priority order: (1) explicit `glob` parameter containing a source extension; (2) `type` parameter matching a known LSP-declared language; (3) explicit `path` pointing at a source file; (4) no glob/type/path specified, meaning the Grep runs workspace-wide — and since `.lsp.json` is declared (the hook's auto-opt-out otherwise applies), the workspace contains source files the Grep will touch.

### When the ask-gate is "wrong" — legitimate proceed cases

The gate is a heuristic. These are the cases where typing "yes" is the right answer:

- **Whole-file Read for refactor.** "I'm about to refactor `PasswordReset.cs` and need to see every method." LSP can give you `documentSymbol` for the outline, but you genuinely need the full text to plan the refactor.
- **Whole-file Read of a small file.** LSP overhead isn't worth it for a 30-line file. Proceed.
- **Whole-file Read after LSP already returned the file path.** You used `workspace/symbol`, got the file path, and want to read the file end-to-end before planning. Proceed.
- **Grep for a literal string that happens to look like an identifier.** E.g., searching for `userId` inside JSON config files, or searching for an enum value name as a literal in test data. LSP doesn't index string contents.
- **Grep against a non-symbol use site.** E.g., searching for `loadConfig` inside markdown documentation. LSP wouldn't help.
- **ctx_execute_file analysis pass over a single source file.** "Count cyclomatic complexity per function" or "find all `[Obsolete]` annotations and their associated text" — analysis work LSP isn't built for.

When proceeding, the audit-tool surveillance section logs the ask-gate event but doesn't track the proceed-vs-deny outcome (the hook can't see the agent's response). The surveillance signal is "how often is the gate firing", not "how often is the gate justified". If it fires noisily but the agent proceeds correctly every time, the precedence rule is the actual fix — strengthen the prompt-side discipline so agents reach for LSP first without needing the hook.

## Languages currently in `.lsp.json`

The hook only ask-gates queries whose target file extension appears in `.lsp.json`. As of this writing, the standard project starter declares: C# (`.cs`, `.csx`, `.cshtml`), Swift (`.swift`), C/C++ (`.cpp`, `.cxx`, `.cc`, `.c++`, `.hpp`, `.hxx`, `.hh`, `.h++`, `.h`, `.c`). Python (Pyright) is documented in starter materials but not always wired; check the project's `.lsp.json` for the authoritative list.

Languages **not** in `.lsp.json` pass through the hook unchanged. If you add a new language to `.lsp.json`, the redirect activates for it automatically — no hook code change needed.

## When neither structural tool can answer — explicit carve-outs

codegraph and LSP are both symbol-aware (codegraph via tree-sitter AST extraction, LSP via the language server). Neither indexes arbitrary text. Some queries look symbol-shaped but actually require text search:

- **Searching for a literal regex inside string contents or comments.** Neither structural tool indexes string literals or comment bodies. Use `Grep` or `ctx_execute` with a grep family tool — and at the ask-gate, type `yes` with a one-line justification.
- **Searching across generated/build artifacts that aren't indexed.** Both tools index the project's source files according to their config; transpiled outputs, vendor directories, or pre-build artifacts may not be indexed. Use `ctx_execute` or `Grep`.
- **Cross-language searches LSP can't span.** LSP's reference graph is per-language. codegraph DOES handle cross-language edges (TS→Python via API call, etc.) for the patterns it recognizes — try it first. For unrecognized cross-language patterns (e.g., dynamic codegen output), use `Grep` or `ctx_execute` with a grep that spans both extensions.
- **Fuzzy or stemmed searches.** Both structural tools match by exact or prefix name (codegraph has FTS5 full-text search via `codegraph_search` which extends the matching surface). For "anything that looks like a password handler", try `codegraph_search` first; if that misses, fall back to `ctx_search` or `Grep`.

If your query falls into one of these carve-outs, proceed at the ask-gate. The justification should name the carve-out: "regex inside comments" or "cross-language symbol via codegen" — that's specific enough to audit later.

## Why this lives in `references/` and not just in subagent prompts

Three reasons.

First, the precedence is shared between subagents (developer, code-reviewer, verification) and the orchestrator's inline-edit Trivial path. One source of truth.

Second, the runtime hook (`check-lsp-first-on-source.sh`) references this file in its ask-gate message, so the user has a single document to consult when the hook fires unexpectedly.

Third, audit-tool drift surveillance (v0.10.5+) reads dispatch logs for `ctx_execute` calls flagged as "source-symbol-shaped but proceeded anyway" and compares against this file's stated carve-outs to decide whether the proceed was justified.

## Auditability

Each ask-gate that gets approved should ideally have a brief reason in the conversation thread — "regex matches comment bodies, LSP can't help". The audit tool's drift surveillance section scans for these explanations; their absence is a soft signal that the agent is reflexively saying `yes` rather than thinking. Soft signal, not a hard error — but worth checking when the audit-tool reports drift.

## Edge cases worth knowing

- **Multi-line `ctx_execute` codeblocks** with both legitimate test runs AND a stray `grep` on a `.cs` file ask-gate the whole block. Refactor the block into two `ctx_execute` calls if one is genuinely a test run and only the other is symbol-shaped.
- **`ctx_batch_execute`** passes its `commands[].code` through the same matcher; if any command in the batch is symbol-shaped, the whole batch ask-gates.
- **`.h` headers** in `.lsp.json` are matched by the hook even though they may also be touched by IDE tooling that pre-resolves includes — the redirect still applies because clangd answers symbol queries for headers too.
- **The hook auto-no-ops if `.lsp.json` is absent.** A project without LSP wired won't see the redirect, even if it lists C# / Swift / C++ files. This is intentional — there is no LSP to redirect to.
