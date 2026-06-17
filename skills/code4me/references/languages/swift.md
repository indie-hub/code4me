# Swift — Plugin-Shipped Language Guidance

Guidance for code-writing subagents working with Swift files (`.swift`). Modern Swift (5.9+, `async`/`await`, actors, value-types-default), with the working norms that distinguish good Swift code from merely-compiling Swift code. The user's project may extend or override any of this via their own `CLAUDE.md` hierarchy; **treat project-specific guidance as authoritative when it conflicts**.

This is not the place for workflow rules (those belong to Code4Me's own machinery). It's the place for what makes Swift good — the language's strengths, the idioms that earn their keep, and the foot-guns to avoid.

---

## The Swift mindset

Two principles dominate everything else. Internalise these and most decisions answer themselves.

- **Clarity over cleverness.** Write code the next engineer can reason about quickly. Apple's API Design Guidelines are the canonical reference for what *clear* looks like in Swift.
- **Safety over shortcuts.** When the compiler nags, it's usually right. The type system is one of Swift's strongest features; don't disable it with `!`, `try!`, `as!`, or `@unchecked Sendable` to get a quick build. Fix the design.

Then, in rough priority:

1. **Correctness.** It does what it's supposed to do, including at the edges.
2. **Clarity.** A reader understands it without you in the room.
3. **Simplicity.** The least machinery that solves the actual problem.
4. **Testability.** You can verify the behaviour without a manual ritual.
5. **Performance.** Fast enough, measured, not assumed.

When these conflict, the higher one wins.

---

## Foundational rules of thumb

- **Boring is good.** Prefer the obvious solution. Cleverness is a tax the next reader pays.
- **Make illegal states unrepresentable.** If a combination of values should never exist, the type system should refuse to express it. `enum` with associated values usually beats a struct of optionals.
- **Push errors and decisions to the edges.** Pure logic in the middle, I/O and side effects at the boundary.
- **YAGNI.** Build for the present, not the imagined future.
- **DRY, but not at any cost.** Two things that look alike but evolve separately should stay separate. Premature abstraction is worse than duplication.
- **Composition over inheritance.** Reach for protocols and structs first; class hierarchies last.

---

## SOLID, applied to Swift

- **Single Responsibility.** Each type does one thing. If you can't name it without "and" or "Manager", split it.
- **Open/Closed.** Extend behaviour via new types and protocol conformances rather than editing existing ones.
- **Liskov Substitution.** A protocol conformance must honour the protocol's contract. No `fatalError` from required methods, no silently ignoring inputs.
- **Interface Segregation.** Many small protocols beat one fat one. Callers depend only on what they use.
- **Dependency Inversion.** High-level code depends on protocols, not concrete types. Inject dependencies; don't reach for globals or singletons.

---

## Type discipline

- **Prefer value types** (`struct`, `enum`) by default. Reach for `class` only when you need identity, shared mutable state, or Objective-C interop.
- **Use `enum` aggressively** for finite states. An `enum` with associated values is almost always clearer than a struct of optionals.
- **`final`** for classes not designed for inheritance.
- **Avoid `AnyObject` / `NSObject`** unless the API actually requires it.
- **No stringly-typed APIs.** If a value has a finite set of meanings, it gets a type.
- **`some`/`any`** are great when they earn their keep — but don't reach for generics if a concrete type is clearer.

---

## Optionals and nullability

- An optional means "this may be absent and that's a normal case." If absence is an *error*, throw instead.
- **No `!` in production code.** No `try!`, no `as!`, no force-unwrapped IBOutlets if avoidable. Use `guard let`, `if let`, or proper error handling.
- `nil`-coalescing (`??`) is fine for genuine defaults. Long optional chains that hide bugs are not.
- **Avoid implicitly unwrapped optionals** unless there's a strong, documented reason.
- **`guard let`** for early exits and preconditions; **`if let`** when the optional path is the body of work.

---

## Naming

- **Clarity > brevity.** `subscriberCount` beats `subCnt`. `cancel()` beats `doCancellationOfTaskNow()`.
- **Apple's API Design Guidelines** (https://www.swift.org/documentation/api-design-guidelines/) are the canonical reference. Read call sites like English where possible. Use argument labels well. Omit needless words.
- **Booleans read as assertions:** `isReady`, `hasFinished`, `canRetry`.
- **Verbs for methods that act**, **nouns for methods that return values without side effects**.
- **No type prefixes** (no `NSString`-style; that's Objective-C).

Convention summary:

- **lowerCamelCase** for variables, functions, parameters, instance methods
- **UpperCamelCase** for types, protocols, enums, modules
- **One type per file**, file name matches the main type

---

## Architecture

- **Layer the code.**
  - *Domain / models:* pure Swift, no UIKit/AppKit/SwiftUI imports, no I/O
  - *Services / use cases:* orchestrate domain logic and adapters
  - *Adapters:* talk to the outside world (network, disk, OS APIs)
  - *UI:* thin; renders state, dispatches intents
- **Dependency direction points inward.** UI depends on services depends on domain. Domain knows nothing about anything else.
- **Inject dependencies through initialisers.** No `@EnvironmentObject` for business logic, no service locators, no `Foo.shared` reaching across the app.
- **Singletons are a smell.** Sometimes justified (a real OS-level resource), usually not. If you use one, write a one-line note explaining why.
- **Protocols at the boundaries, concrete types in the middle.** A protocol earns its place when there's a real second implementation (a fake for tests counts).

---

## Concurrency

- **Default to Swift Concurrency.** `async`/`await`, `Task`, actors, structured concurrency. Don't reach for GCD, `DispatchQueue`, `NSLock`, or `OperationQueue` unless you have a specific reason — and a comment explaining it.
- **Use actors for shared mutable state.** That's what they're for.
- **`@MainActor`** for UI-touching code. Mark it explicitly; don't rely on ambient context.
- **Prefer structured concurrency.** Use `async let` and task groups over detached `Task { }` blocks. Unstructured tasks should be rare and named.
- **Honour cancellation.** Long-running work checks `Task.isCancelled` or uses cancellation-aware APIs. Don't swallow `CancellationError`.
- **`Sendable` is not optional.** When the compiler complains, fix the design; don't paper over it with `@unchecked Sendable`.
- **No data races.** If you're reaching for a lock, ask whether an actor would be cleaner.

---

## Error handling

- **Throwing functions** for recoverable failures. `Result<T, E>` is fine at API boundaries that need to be passed around as values.
- **Typed throws** where the error set is small and stable; untyped throws when it isn't.
- **Define your own error enums** at module boundaries. Don't leak `NSError` or third-party errors upward.
- **Never silently swallow errors.** No empty `catch { }`. At minimum, log with context.
- **`fatalError` / `preconditionFailure`** are for genuine programmer errors — invariants that should be impossible. Not for "I haven't handled this yet."
- **Validate at the edges.** Once a value is inside the domain, it should be trusted because the type says so.

---

## SwiftUI vs UIKit / AppKit

- **Prefer SwiftUI** for new views. Use UIKit/AppKit only when the project requires it or SwiftUI can't deliver something specific.
- **SwiftUI views stay thin.** Render state, dispatch intents. Business logic belongs in view models (`@Observable`, `ObservableObject`) or domain services, not in `body`.
- **Property wrappers used appropriately:**
  - `@State` for local, simple value state
  - `@StateObject` (or `@State` with `@Observable` types) for owning reference-type models
  - `@ObservedObject` (or just a let) for injected models
  - `@EnvironmentObject` sparingly, for truly global app state
- **Extract subviews** when a view grows. Six-line `if let`/`guard` chains are fine; deeply nested ternaries inside `body` are not.
- **Avoid `DispatchQueue.main.async { ... }`** as a fix for threading bugs you don't understand. Find the actual bug — usually it's missing `@MainActor`.

---

## Testing

- **Use Swift Testing** (`@Test`, `#expect`) for new test files where the toolchain supports it; XCTest is fine where it's already established. Match the project.
- **Test behaviour, not implementation.** A test that breaks when you refactor internals without changing behaviour is a bad test.
- **Arrange / Act / Assert** with blank lines between them. One logical assertion per test where reasonable.
- **Name tests as sentences** — `returnsEmpty_whenInputIsEmpty`, `throwsNotFound_whenIDMissing`. The name is the spec.
- **Fast and isolated.** Unit tests don't touch disk, network, or the clock. Inject those.
- **Fakes over mocks.** A small in-memory implementation of a protocol is usually clearer and more durable than a mocking framework.
- **Cover the boundaries:** empty, single, many, max, malformed, cancelled, concurrent.
- **Snapshot tests** are useful for SwiftUI views and complex output, but treat failures as questions, not annoyances — review diffs, don't blindly re-record.

---

## Documentation and comments

- **`///` doc comments** on every `public` symbol. State what it does, what it returns, what it throws, and any preconditions.
- **Comments explain *why*, not *what*.** The code shows what; the comment explains the non-obvious reason.
- **Delete dead code** instead of commenting it out. Git remembers.
- **A short README per module** describing its purpose and entry points pays for itself within a week.

---

## Project structure and tooling

- **Swift Package Manager** is the default. Use SPM for modules; only carry an `.xcodeproj` when you need things SPM can't do (entitlements, certain resources, complex schemes).
- **Modularise by feature or domain**, not by type. `Authentication` as a module beats `Models` / `Views` / `ViewModels`.
- **Public surface is deliberate.** Default to `internal`; mark `public` only what consumers need. Use `private`/`fileprivate` over `internal` when scope allows.
- **`xcconfig` files** for build settings, not Xcode UI checkboxes — settings should be diffable.

---

## Dependencies

- **Fewer is better.** Every dependency is a long-term liability.
- Before adding one: is it maintained, is it small, does it pull in transitive weight, can we vendor a 50-line version instead?
- Pin versions. Update deliberately, with a changelog skim.
- Prefer Apple frameworks where they're good enough.

---

## Apple platform specifics

- **Sandboxing and entitlements:** know what the app needs and ask for nothing more.
- **App lifecycle:** prefer SwiftUI's `App` and scenes. Reach for AppKit/UIKit only for what SwiftUI can't do, and isolate it behind a protocol.
- **File system:** use `URL`-based APIs (not `String` paths). Use `FileManager` carefully — most of its APIs throw.
- **User defaults:** fine for small preferences, not for app state. Wrap access behind a typed facade so it's mockable.

---

## Things to avoid

- Force unwraps and force casts in production paths
- `Any` and `AnyObject` outside of true bridging code
- Singletons used as global mutable state
- View controllers / SwiftUI views with business logic baked in
- Inheritance hierarchies more than one level deep without a clear reason
- Closures captured `[unowned self]` when `[weak self]` is correct
- `DispatchQueue.main.async { ... }` as a "fix" for threading bugs you don't understand
- Premature protocols (one type, one conformance, no test reason)
- "Utility" / "Helper" / "Manager" types that accumulate unrelated functions
- Silent `try?` that converts errors to `nil` and hides real failures

---

## When in doubt

Ask. A two-line clarifying question now is cheaper than a 200-line wrong-shaped diff later. Read the existing code in the same module. Project conventions trump generic guidance. Match what's there even if it isn't your favourite — consistency beats local optimums. If you find yourself making a choice that contradicts existing patterns, surface that as an INSIGHT (per `references/insight.md`) rather than introducing a new style silently.
