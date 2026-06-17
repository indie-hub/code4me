# C++20 — Plugin-Shipped Language Guidance

Guidance for code-writing subagents working with C and C++ files (`.cpp`, `.cxx`, `.cc`, `.c++`, `.hpp`, `.hxx`, `.hh`, `.h++`, `.h`, `.c`). Opinionated C++20: the rules below are firmer than for most languages because C++ punishes ambiguity. The user's project may extend or override any of this via their own `CLAUDE.md` hierarchy; **treat project-specific guidance as authoritative when it conflicts**.

This is not the place for workflow rules (those belong to Code4Me's own machinery). It's the place for what makes C++20 good — the principles that compose into safe, fast, maintainable code, and the discipline that makes C++ readable instead of regrettable.

---

## Principles to keep in front of you

- **SOLID & Clean Code.** Single Responsibility, Open/Closed, Liskov, Interface Segregation, Dependency Inversion. Small functions with intention-revealing names. No magic numbers. Minimise mutable state. Fail fast. Clear boundaries.
- **C++ Core Guidelines.** Lifetime safety, RAII, `std::unique_ptr` over raw owning pointers, `std::span<T>` and `std::string_view` for views.
- **Composition over inheritance.** Mark `final` where appropriate. Reach for inheritance hierarchies last.
- **Explicit APIs.** Avoid implicit conversions. Prefer `explicit` constructors.
- **Boring is good.** Prefer the obvious solution. Cleverness is a tax the next reader pays — especially in C++ where the type system has many ways to express the same thing.

---

## The "always" rules

These are firm, not preferences. They protect against C++'s sharper edges.

### Always use braces

Even for single-line `if`/`for`/`while`/`return` blocks. Single-line bodies are bug surfaces (the dangling-else, the macro-expansion-changes-shape, the *"just one more statement"* refactor that breaks scope). Braces cost nothing and prevent a class of silent failures.

### Always use angle-bracket includes

`#include <project/module/foo.hpp>` for project headers. `#include <vector>` for system/library headers. **Quoted includes (`#include "..."`) are prohibited.** Angle brackets force the include path to go through the build system's configured include directories, which keeps include resolution explicit and predictable. Quoted includes are the classic source of *"works on my machine, breaks on theirs"* dependency drift.

The build system needs to be configured so project headers resolve via angle brackets — that's a CMake / build-system concern handled in the project's `CMakeLists.txt` (`target_include_directories(... PUBLIC include)` or similar). Don't paper over a misconfigured build system by reaching for quoted includes.

### Always initialise fields

Every member variable must be initialised, either with in-class initialisers or via constructor initialiser lists. Uninitialised data is undefined behaviour waiting to manifest under release builds, different compilers, or different inputs.

```cpp
class Widget {
public:
    explicit Widget(int size) : m_size{size} {}

private:
    const int m_size {0};                      // in-class default
    bool      m_isReady {false};
    static constexpr int s_defaultCapacity {16};
};
```

### Prefer brace initialisation

Use `{}` over `=` or `()` when constructing values. It avoids narrowing conversions and the *"most vexing parse"*. The exceptions are when `std::initializer_list` overload resolution would surprise you (e.g., `std::vector<int> v(10)` makes ten zero-initialised ints; `std::vector<int> v{10}` makes a vector with one element `10`) — in those cases be explicit and comment.

### Use `const` whenever possible

Variables, parameters, member functions, pointers — apply `const` everywhere immutability holds. Const-correctness compounds: once you start, the compiler tells you where you violate it. Adding `const` after the fact is painful in a non-const codebase.

### Use `constexpr` and `consteval` where appropriate

Compile-time constants and evaluation improve safety, clarity, and performance. `constexpr` for "this can be compile-time"; `consteval` for "this must be compile-time". When you can express a function as `constexpr`, do.

### Use `noexcept` whenever possible

Mark functions `noexcept` when you can guarantee they won't throw. The compiler optimises differently around `noexcept` boundaries (especially in containers and move operations), and the annotation is a contract for callers.

### Prefer `std::array` over C-style arrays

Always reach for `std::array<T, N>` rather than `T[]` for fixed-size arrays. `std::array` carries its size, doesn't decay to a pointer, and integrates with the standard library's algorithms.

---

## Modern C++20 practices

- **`std::unique_ptr`** for ownership; **`std::shared_ptr`** only when shared ownership is genuinely needed.
- **`std::span<T>`** and **`std::string_view`** for non-owning views; pass these in parameter lists rather than `const T&` for ranges of data.
- **Ranges and algorithms** (`<ranges>`, `<algorithm>`) preferred over manual loops when readability improves.
- **Concepts** for light template constraints; concept-driven errors are vastly clearer than SFINAE-driven ones. Avoid over-templatisation.
- **Coroutines** only with a clear scheduler/runtime and tests. They're powerful and easy to get wrong.
- **`std::expected<T, E>`** (C++23 if available; project may have a polyfill or boost equivalent) for recoverable error returns.
- **Structured bindings** (`auto [x, y] = pair`) for tuple-like decomposition.
- **`if constexpr`** for compile-time branching inside templates.

---

## Ownership semantics

- **`std::unique_ptr<T>`** — exactly one owner; transfers via move
- **`std::shared_ptr<T>`** — shared ownership; pays atomic-refcount cost. Don't reach for it where `unique_ptr` would do.
- **`std::weak_ptr<T>`** — break cycles, observe without owning
- **`T&`** — non-owning, non-null reference for borrowing
- **`const T&`** — read-only borrowing
- **`T*`** — non-owning, possibly-null reference (use sparingly; usually a reference is better)
- **`std::span<T>`** / **`std::string_view`** — non-owning views over contiguous data; passed by value

Raw owning pointers are forbidden in modern code. If you see `new` not paired with a smart pointer, that's a finding.

---

## Error handling — pick one, don't mix

Within a project (or at minimum within a module), pick a single error-handling discipline:

- **`std::expected<T, E>`** for recoverable errors at API boundaries. The caller sees the failure at the type level and must handle it.
- **Exceptions** for genuinely exceptional conditions (programmer errors, OS failures, invariants violated). Narrow scope; not for control flow.
- **Plain return values + bool/optional** when the failure is "absent" rather than "wrong".

**Do not mix exceptions and `std::expected` for the same kind of failure.** Pick one for the project's recoverable-error path and stick to it. Mixing produces the worst of both: callers can't reason about which functions throw, and the type system isn't carrying the failure mode.

For genuinely exceptional cases, exceptions remain valid. Just don't reach for them when `std::expected` (or a domain `Result<T, E>` type) would let the type system carry the contract.

---

## Concurrency

- **`std::jthread` + `std::stop_token`** over raw `std::thread`. Cooperative cancellation is the default.
- **Isolate shared state** behind small, tested abstractions. A class with a `std::mutex` and well-defined accessors beats a free-floating mutex visible to many call sites.
- **`std::scoped_lock`** / `std::lock_guard` / `std::unique_lock` over manual `lock()`/`unlock()`.
- **Coroutines for asynchronous control flow** when the project has chosen a coroutine runtime; otherwise traditional `std::async`/`std::future` or thread-pool patterns.
- **Don't share what you don't need to share.** Most concurrency bugs come from shared mutable state that didn't have to be shared.

---

## Build, format, and tooling expectations

These are project-shape but worth confirming when you start:

- **`compile_commands.json`** at the project root or `build/` is what clangd needs. CMake produces this with `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`. Without it, clangd's diagnostics are unreliable.
- **`.clang-format`** at the project root governs formatting. The project's baseline is likely Allman braces, 4-space indent, 120 column limit, sorted includes regrouped.
- **`.clang-tidy`** governs static-analysis rules. Don't disable diagnostics without justification.
- **Compiler warnings** should be on: `-Wall -Wextra -Wpedantic -Wconversion` on GCC/Clang; `/W4 /permissive-` on MSVC. Code compiles with zero warnings.

---

## Testing

- **Catch2** or **GoogleTest** are the common choices. Use whichever the project has.
- **Deterministic, hermetic unit tests.** No real time, no real disk, no real network. Inject those.
- **Coverage**: target ≥ 80% for core modules. Measure but don't game.
- **Test names as sentences** describing behaviour (`returnsEmpty_whenInputIsEmpty`, `throwsNotFound_whenIDMissing`).
- **Test boundaries**: empty, single, many, max, malformed.

---

## C++ standard, compiler, build-system version checks

C++ projects vary so much that *"use C++"* is barely a statement. Confirm before writing:

- **C++ standard version** (17 / 20 / 23). Don't use features the project's compiler doesn't support.
- **Build system** (CMake / Bazel / Meson / etc.). The build files tell you what's compiled and how.
- **Exception policy** — some projects forbid exceptions (game engines, embedded, certain teams).
- **RTTI** — sometimes disabled. `dynamic_cast` won't work.
- **Standard library** — usually `std::`, sometimes EASTL or Abseil or custom. Match what the project uses.

If any of this is unclear from project context, return `outcome: NEEDS_CLARIFICATION` rather than guessing. Wrong assumptions in C++ are expensive — undefined behaviour is the default failure mode.

---

## The Rule of Zero (and Five)

The Rule of Zero is the goal: design types whose members handle their own lifetimes, so you don't write any of the special members (destructor, copy ctor, copy assign, move ctor, move assign).

The Rule of Five: if you write any of those five, think carefully about all five. Use `= default` and `= delete` explicitly when the implicit special members would be wrong.

---

## Common pitfalls

- **Undefined behaviour** is silent. It may not manifest until release builds, different compilers, or different inputs.
- **Lifetime issues** — dangling references after returning local addresses, references to vector elements after reallocation.
- **Iterator invalidation** — modifying a container while iterating over it.
- **Implicit conversions** — between numeric types, between pointers and bool, between enums and ints. `explicit` and warning flags catch most of these.
- **Static initialisation order fiasco** — globals across translation units have no defined initialisation order.
- **`auto&&`** is a forwarding reference, not always rvalue. Be aware of forwarding-reference semantics.
- **`std::move` doesn't move** — it casts to rvalue; the receiving operation moves. Calling `std::move` on something then continuing to use it is a footgun.
- **Copying when moving was intended** — pass by value for sink parameters, then move; or use `T&&` and `std::move`.
- **ABI breaks** — changes to type layout, virtual table, exported symbol set break binary compatibility. Worth flagging when you cross that line.
- **Header-include creep** — every header you include in a public header transitively imposes the include on every consumer. Forward-declare in headers; include in `.cpp`.

---

## When in doubt

Read existing code in the same module. C++ projects vary so much that generic guidance often loses to project conventions. Surface ambiguity as INSIGHTs or as `NEEDS_CLARIFICATION` rather than silently introducing a new style. Wrong choices in C++ are unusually expensive to undo.
