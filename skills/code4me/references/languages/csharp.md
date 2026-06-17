# C# (Unity) — Plugin-Shipped Language Guidance

Guidance for code-writing subagents working with C# in **Unity** projects (`.cs`, `.csx`, `.cshtml`). Unity-flavoured: this file diverges from canonical .NET style in places where Unity demands it. The user's project may extend or override any of this via their own `CLAUDE.md` hierarchy; **treat project-specific guidance as authoritative when it conflicts**.

This is not the place for workflow rules (those belong to Code4Me's own machinery). It's the place for what makes C# in Unity good — the principles, the idioms, and the traps the language and engine combine to produce.

---

## Principles to keep in front of you

The project may already state these; they're worth seeing again at task start because subagents don't always inherit the full project context.

- **SOLID & Clean Code.** Single responsibility, explicit dependencies, small cohesive classes, meaningful names, refactor mercilessly. *"Manager"* and *"Helper"* are smells.
- **Clarity over cleverness.** Write code the next engineer can reason about quickly.
- **Determinism first.** Reduce hidden state. Avoid magic side effects. Make time and randomness injectable.
- **Composition over inheritance.** Reach for small focused types and protocol-style abstractions before class hierarchies.
- **Performance is a feature.** Measure, profile, then optimise. No cargo-cult micro-optimisations.
- **Toolable assets.** Prefer Addressables, prefabs, and ScriptableObjects to encode data, not code.

---

## Unity discipline (the part that diverges)

Unity is a C# project living inside a game engine. The engine's lifecycle, asset model, and `UnityEngine.Object` semantics override defaults you'd otherwise reach for in plain .NET.

### POCO-first, MonoBehaviours as adapters

Domain logic lives in plain C# classes (POCOs) and ScriptableObjects. MonoBehaviours are thin adapters wiring the engine to the domain — they should be small, expose serialised configuration, and delegate.

A good signal you've got it right: most of your unit tests cover plain C# (Edit Mode tests), and the MonoBehaviour layer is exercised by a few Play Mode tests in lightweight scenes.

### Serialised private fields, no public fields

Fields are **private** with `[SerializeField]` for inspector exposure. Public access goes through properties or methods. The engine's serialisation respects `[SerializeField]` on private fields, so you don't lose the inspector ergonomics by being properly encapsulated.

### Naming: `m_` prefix on private fields

Private fields use the `m_` prefix: `m_Speed`, `m_Player`, `m_HasInitialised`. This is a Unity-house convention; it disambiguates fields from locals and parameters at a glance, and Rider/StyleCop configs in the project enforce it.

This contradicts canonical .NET style (which prefers `_camelCase` or no prefix). Follow the project. When existing files contradict canonical .NET style, the project wins — consistency in the codebase matters more than canonical style elsewhere.

### Always use braces

Always use `{ }`, even on single-line `if`/`for`/`while` bodies. Single-line blocks are bug surfaces; the brace cost is negligible.

### Explicit types, no `var`

Do not use `var`. Use the concrete type. The reason in Unity context: code is often read in diff form during code review or in the engine's editor scripts; explicit types remove a layer of inference for the reader. If the type name is repetitive, that's a signal to refactor, not to hide it.

### The Unity null trap

This is the rule most likely to bite a generic-C# subagent. **`UnityEngine.Object` (MonoBehaviours, ScriptableObjects, GameObjects, Components) overloads `==`**, so:

- **Never use `??`, `??=`, `?.`, or `is null`** with Unity objects. They use C# language null rules, not Unity's `==` overload, and will treat *destroyed-but-not-yet-collected* Unity objects as non-null when they should be considered null.
- **Always use `if (obj == null)`** for Unity objects.
- **Never use `ReferenceEquals(x, null)`** with Unity objects — it will not detect destroyed instances.
- For coalescence-style fallbacks on Unity objects, use explicit conditionals or small typed helper methods.

For plain C# objects (POCOs, value types, framework types not derived from `UnityEngine.Object`), modern null-handling operators are fine.

### Update usage

Avoid per-frame `Update()` unless necessary. Prefer events, coroutines, or centralised tick systems. Per-frame work is the most common source of GC pressure and frame-time issues; if you don't need every frame, don't subscribe to every frame.

### URP first

Target Universal Render Pipeline. Author shaders, materials, and renderer features for URP by default. Don't reach for built-in render pipeline patterns unless a specific reason warrants it.

### Threading

Unity APIs are main-thread only. `async`/`await` for I/O and long-running CPU work is fine; just don't touch `UnityEngine` types off the main thread. Use Job System / Burst thoughtfully when you do need parallelism, with clear ownership.

---

## Modern C# practices (in Unity context)

- **`using` declarations** (C# 8+) over `using(...) {}` blocks when lifetime matches the full method scope and doesn't conflict with Unity's execution order.
- **`foreach`** for readability when iterating; `for` only when index-based access is needed.
- **Inline `out` declarations** (`if (int.TryParse(x, out int value))`) for clarity.
- **Pattern matching** when it improves readability and doesn't hide Unity-specific null semantics — the `is null` rule above still applies.
- **String interpolation** over concatenation (`$"Score: {m_Score}"`). For aggregating many strings in non-hot paths, `StringBuilder`. Avoid string-building in tight per-frame loops.
- **`IReadOnlyList<T>` / `IEnumerable<T>`** in public APIs when mutation is not required.
- **Field initialisers** preferred over assignment in constructors, but be careful with anything that depends on the Unity lifecycle (the constructor runs before `Awake`/`Start`, so engine references aren't ready yet).
- **Immutable data types** (readonly fields, init-only setters, records) for configuration and DTO-style objects.

LINQ is fine in non-hot code paths for clarity. Avoid deep LINQ chains and allocations in tight loops or per-frame code. Don't modify a collection while iterating it; collect changes first.

---

## Error handling

- Exceptions for **exceptional conditions**, not for normal control flow.
- Validate inputs early (guard clauses); fail fast with clear, contextual messages rather than silent no-ops.
- Centralise logging through a small helper rather than scattering `Debug.Log*` calls.
- Don't catch `Exception` unless you genuinely need a sweeping handler at a top-level boundary.
- `throw` (preserves stack trace), not `throw ex`.

---

## Async / await in Unity

- `async`/`await` for I/O or long-running work that doesn't touch Unity APIs.
- All `UnityEngine` calls stay on the main thread. If you spawn work on a thread pool, don't touch the engine from it.
- Avoid `.Result` and `.Wait()` — they cause deadlocks. Make call sites async instead.
- `CancellationToken` parameters are last and named `cancellationToken`.
- Methods returning `Task` or `Task<T>` suffix with `Async`.
- Don't `await` inside tight per-frame loops.

For Unity-flavoured async, also consider `UniTask` if the project uses it (the project's existing code is the source of truth on this).

---

## Asset and naming conventions (commonly enforced)

If the project has these (or variants), follow them. The validator probably enforces them and CI will fail otherwise:

- Textures: `t_<Feature>_<Name>_<Size>` (e.g., `t_UI_Button_512`)
- Materials: `m_<Feature>_<Name>`
- Meshes/Models: `md_<Feature>_<Name>`
- Prefabs: `pf_<Feature>_<Name>`
- Scripts: `Feature_ComponentName.cs` (one class per file)
- Addressables: grouped by feature; labels for platform/quality tier

Confirm with existing project files before naming new assets.

---

## Testing strategy

- **Edit Mode tests** for pure logic (parsers, math, data mappers, domain calculations). These cover the POCO layer and run fast.
- **Play Mode tests** for behavioural tests in lightweight scenes. Avoid real-time waits; use fakes/stubs.
- Design core logic as pure functions where possible so Edit Mode coverage is straightforward.
- Keep MonoBehaviour behaviour small and composable so Play Mode tests can exercise them in tiny scenes.
- Test naming: `MethodName_Scenario_ExpectedBehaviour` or Given/When/Then equivalent.

---

## Common Unity-flavoured pitfalls

- **Force-unwrap-style assumptions about destroyed objects** — see the null trap above. The cardinal sin.
- **Per-frame allocations** — every `new`, `string +`, LINQ chain, or boxed value type in `Update()` is a GC trigger. Steady-state should be 0 bytes / frame on Quest-class targets.
- **Constructors doing engine work** — the constructor runs before `Awake`/`Start`. Don't `FindObjectOfType` or touch other components in it.
- **`Coroutine` capture of destroyed MonoBehaviours** — coroutines stop when the host MonoBehaviour is destroyed, but if you've captured `this` in a longer-lived structure the reference holds the GameObject alive in unexpected ways.
- **Singletons** — `static` instances are tempting and rapidly become hidden coupling. Prefer the bootstrap-scene service-locator pattern when you need shared services, and limit it to startup.
- **`Instantiate` and `Destroy` in tight loops** — both are expensive. Pool instead.
- **Public fields creeping back in** — *"just for the inspector"* is the gateway. Use `[SerializeField] private` instead.
- **Hard-coded paths to scenes/assets** — Addressables exist precisely so you don't.

---

## When in doubt

Read the existing code in the same module. Project conventions trump generic guidance. If the project's existing files contradict any of this — different field naming, different render pipeline, no Addressables, different test framework — follow the project. Surface conflicts as INSIGHTs (per `references/insight.md`) rather than introducing a new style silently.
