# Python — Coding Reference

Generic-opinionated Python guidance, in the spirit of the plugin's other language references. The project's `CLAUDE.md` (root or hierarchical) authoritatively overrides this baseline.

## Mindset

Python is meant to be read. Code is written once and read many times; optimise for the reader. When you can choose between a clever one-liner and a clear three-liner, choose the three-liner. The Zen of Python (`import this`) is the canonical statement of the language's values — "explicit is better than implicit," "readability counts," and "if the implementation is hard to explain, it's a bad idea" are load-bearing, not aspirational.

Priority order when in tension:

1. **Correctness** — does it produce the right answer?
2. **Clarity** — can someone reading this in six months understand what it does and why?
3. **Simplicity** — fewer concepts and fewer dependencies, all else equal
4. **Testability** — can it be exercised without the production environment?
5. **Performance** — only when measured matters; profile before optimising

## Tooling baseline

Adopt these unless your project has stated reasons against:

- **`ruff format`** (or `black`) for formatting. Single canonical style; no style debates.
- **`ruff check`** for lint. Subsumes pyflakes, isort, pyupgrade, and most pylint rules at much higher speed.
- **`pyright`** for type-checking (or `mypy` if your team already uses it). Strict mode opt-in for new code via `pyrightconfig.json` or `[tool.pyright]` in `pyproject.toml`.
- **`pytest`** for tests. Fixtures and parametrize over unittest's `setUp`/`tearDown`.
- **`uv`** or **`poetry`** for dependency management and virtualenv. `pip install` into the global Python is a code smell.

`pyproject.toml` is the canonical manifest. Avoid `setup.py` and `setup.cfg` in new projects.

## Naming and style

Follow PEP 8 with the standard Pythonic conventions:

- `snake_case` for functions, variables, modules, and package directories
- `PascalCase` for classes and type aliases
- `SCREAMING_SNAKE_CASE` for module-level constants
- `_leading_underscore` for "intended private" (a convention; not enforced by the runtime)
- `__dunder__` reserved for Python's protocol methods — do not invent your own
- `_unused` (single underscore) on locals or loop variables you don't intend to use
- Module names are short, lowercase, and avoid underscores when readable without them; package directories likewise

Line length: 88 (`ruff format` / `black` default) or 100 if your team has agreed. PEP 8's strict 79 is too tight for modern displays.

## Type hints

Type hints (PEP 484+) earn their keep at API boundaries and on dataclasses. Use them on:

- Every public function signature
- Every public class attribute (especially in dataclasses)
- Module-level constants when the type isn't obvious from initialisation
- Complex local variables when the type would aid the reader

Skip them on:

- Trivial locals where the type is obvious
- One-off helper functions used in a single tight scope

Conventions:

- Use `from __future__ import annotations` at the top of every module in new projects — PEP 563 deferred evaluation lets you reference types defined later in the file and avoids runtime cost of evaluating annotations.
- Use built-in generics (`list[int]`, `dict[str, MyClass]`) when targeting Python 3.9+; `typing.List` etc. is older style.
- `Optional[X]` and `X | None` are equivalent in modern Python; prefer `X | None` for new code (3.10+).
- `Any` is an escape hatch — every use of `Any` is a place the type system has surrendered. Limit deliberately.
- Prefer `Protocol` over abstract base classes when the consumer doesn't need inheritance — structural typing is more Pythonic than nominal.

## Data shape

Three layers, in order of preference:

1. **Frozen dataclasses** (`@dataclass(frozen=True)`) for value objects. Immutable by default; equality and `__repr__` for free; type-hint discoverable.
2. **Pydantic models** when you need runtime validation (parsing user input, API boundaries, config loaded from files). Pydantic v2 is the current; v1 is deprecated.
3. **Plain dicts** only when the data genuinely is a flat key-value map and you don't care about its shape (config splatting, kwargs forwarding).

`namedtuple` and `TypedDict` exist but are usually inferior. Namedtuples are positional and gain little from their immutability; TypedDicts provide static-only checks without runtime structure or methods.

## Error handling

Python uses **EAFP** ("easier to ask forgiveness than permission") over LBYL ("look before you leap"). Try the operation; catch the exception if it fails. `try`/`except` is cheap; the alternative (`if hasattr(x, 'y'): x.y(...)`) is racy and verbose.

Rules:

- **Never bare `except:`.** It catches `KeyboardInterrupt` and `SystemExit`. Use `except Exception:` if you genuinely need to catch everything; preferably list the specific exception types you expect.
- **Don't catch and re-raise without doing anything useful.** Either handle the exception, transform it (`raise NewError(...) from original`), or let it propagate. A bare `except: raise` adds nothing.
- **Use `with` for resource management.** Files, locks, network connections, anything with a `close()` method. Custom context managers via `@contextmanager` (preferred for stateless cases) or `__enter__`/`__exit__` (for stateful ones).
- **`try`/`except`/`else`/`finally`:** `else` runs only when no exception was raised; `finally` always runs. Use `else` for the success path so the `try` body is the smallest possible scope where the expected exception can fire.

Custom exception classes: subclass the closest standard exception (`ValueError`, `TypeError`, `RuntimeError`) or a domain-specific base. Don't subclass `Exception` directly unless you genuinely mean "any kind of error."

## Concurrency

Python's GIL means **threading doesn't give you CPU parallelism** — threading is useful for I/O-bound work where threads spend most of their time blocked. For CPU-bound work, use multiprocessing or a native extension.

Three patterns, pick by shape of work:

- **`asyncio`** (`async def` + `await`) for I/O concurrency at scale — hundreds of concurrent connections, structured cancellation, explicit suspension points. Idiomatic for modern web frameworks (FastAPI, aiohttp). Viral: async functions can only be awaited from async contexts.
- **`concurrent.futures.ThreadPoolExecutor`** for I/O concurrency at modest scale — a handful of parallel HTTP calls, batched database queries. Simpler than asyncio; usable from sync code.
- **`concurrent.futures.ProcessPoolExecutor`** (or `multiprocessing.Pool`) for CPU-bound parallelism above the GIL.

Asyncio caveats worth knowing up-front:

- Async and sync interop is awkward. Mixing them produces accidental blocking that's hard to debug. Pick one paradigm per module.
- CPU-bound work inside an async function blocks the event loop. Use `asyncio.to_thread` or `loop.run_in_executor` to offload.
- `asyncio.gather` for parallel awaits with one of them failing; `asyncio.create_task` to fire-and-track; `asyncio.timeout` (3.11+) over `wait_for`; `asyncio.TaskGroup` (3.11+) for structured concurrency.

## Common traps

- **Mutable default arguments.** `def f(x=[]):` shares the list across calls. Use `def f(x=None): x = x if x is not None else []`. Same for `dict`, `set`, and other mutable types.
- **Late-binding closures.** Loops that create lambdas capture the *variable*, not its value:
  ```python
  fns = [lambda: i for i in range(3)]      # all return 2
  fns = [lambda i=i: i for i in range(3)]  # default-arg trick fixes it
  ```
- **`is` vs `==`.** `is` checks identity (same object); `==` checks equality (same value). Use `is` only for `None`, `True`, `False`, and other singletons. Everything else uses `==`.
- **Falsy edge cases.** `[]`, `{}`, `""`, `0`, `0.0`, `None` are all falsy. `if my_list:` is fine to mean "list is non-empty"; `if my_count:` is a bug waiting to happen when `0` is a valid value. Compare explicitly: `if my_count is not None:`, `if len(my_list) > 0:`.
- **Import cycles.** Tend to surface late. Resolve by moving the shared dependency to a third module, deferring imports inside functions (acceptable for cycle-breaking), or `if TYPE_CHECKING:` for type-only imports.
- **Generator exhaustion.** Generators are single-use. After one iteration, the generator is empty. Convert to `list` if you need to iterate twice.
- **String concatenation in loops.** `result += new_part` in a loop is O(n²) for strings. Use `"".join(parts)` instead.
- **Modifying a list while iterating it.** Same trap as in any language; collect changes first, apply after.
- **`==` on dataclasses with `eq=False`.** Reverts to identity. Default `eq=True` is almost always what you want.

## Testing with pytest

- **Functions, not classes.** `def test_thing():` at module scope. Inherited `unittest.TestCase` classes are noisier and harder to parametrize.
- **Fixtures over `setUp`/`tearDown`.** `@pytest.fixture` provides dependency injection; one fixture per piece of test infrastructure; compose them.
- **Parametrize for variants.** `@pytest.mark.parametrize` over a hand-rolled loop. Each parameter set produces a separate test case in the output, with its own pass/fail.
- **`tmp_path` over `tempfile.mkdtemp`.** Built-in fixture that gives you a unique temp directory and cleans up automatically.
- **Mocking:** `unittest.mock` (standard library) or `pytest-mock`. Mock the *boundary* (the database client, the HTTP client), not the unit you're testing.
- **One logical assertion per test.** Multiple assert statements in one test obscure which one fired. If a single behaviour needs multiple checks, that's fine — but a single test asserting multiple unrelated things is two tests pretending to be one.

Test layout: tests in `tests/` mirroring the `src/` structure. One test module per source module: `src/foo.py` → `tests/test_foo.py`.

## Project layout

For libraries and applications:

```
my-project/
├── pyproject.toml
├── README.md
├── src/
│   └── my_package/
│       ├── __init__.py
│       └── ...
└── tests/
    └── test_*.py
```

The `src/` layout (over a flat `my_package/` at the repository root) prevents accidental imports from the working directory rather than the installed package — catches packaging mistakes early. For one-off scripts and small CLIs, a flat layout is fine; `pyproject.toml` is still the manifest.

`__init__.py` files are required for traditional packages. Python 3.3+ supports namespace packages without them, but they have surprising behaviour around module discovery — prefer explicit `__init__.py` unless you have a specific reason for namespace packages.

## Dependencies

- Use `pyproject.toml` with the `[project]` dependencies block; dev tools under `[project.optional-dependencies.dev]` or `[dependency-groups.dev]`.
- Lock files (`uv.lock`, `poetry.lock`, or `pip-tools`-generated `requirements.txt` pins) belong in git. They're the reproducibility contract.
- Pin major versions for production dependencies (`requests >= 2,<3`); avoid pinning patch versions unless you have a stated reason.
- Separate prod and dev dependencies. Don't ship `pytest`, `ruff`, or `pyright` in your distribution.

## When in doubt

The project's `CLAUDE.md` (root or hierarchical) authoritatively overrides this baseline. Plugin-shipped guidance is generic — your project's voice wins. If you observe a conflict between this file and the project's conventions, surface it as an INSIGHT to the orchestrator (per `references/insight.md`) so the conflict can be resolved at the cerebrum, project-CLAUDE.md, or guidance-amendment layer rather than silently following either side.
