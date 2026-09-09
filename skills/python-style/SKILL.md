---
name: python-style
description: House Python conventions — naming, imports, typing, class design, encapsulation, config, error handling, logging, comments, state, and tests. Use when writing or reviewing any Python in my projects, starting a new repo, adding a module or service, or on phrasings like "review this code", "structure this project", "set up ruff", "is this pythonic".
---

# Python style

Conventions that tooling can't enforce. Spacing, import order, quote style, and
line length are `ruff`'s job.

- Project layout — boundaries, dependency direction, choosing the axis: [references/layouts.md](references/layouts.md)
- Repo setup — ruff, pre-commit, pinning, mypy: [references/tooling.md](references/tooling.md)
- Testing: [references/testing.md](references/testing.md)
- Drop-in config: [references/pyproject-template.toml](references/pyproject-template.toml)

## Naming

| Kind | Form | Example |
|---|---|---|
| module, function, variable | `snake_case` | `api_client.py`, `fetch_page` |
| class | `PascalCase` | `BaseFetcher` |
| module constant | `SCREAMING_CASE` | `DEFAULT_PAGE_SIZE` |
| internal attr / method | `_leading` | `self._client`, `_build_query()` |
| subclass-collision guard | `__leading` | `self.__buffer` |

Acronyms follow the surrounding name: `http_client.py`, `api_io.py` — never
`httpClient.py`.

`_single` is the default for internals. `__double` mangles (`__buffer` inside
`Loader` → `_Loader__buffer`), so a subclass gets a *different* attribute instead
of overriding and tests must spell the mangled name — use it only to protect base
state, with a comment saying why.

Names carry units and intent: `max_requests_per_run`, `fetched_at`,
`timeout_seconds`.

## Imports

Absolute from the package root: `from mypkg.lib.config import Config`.

No side effects at import time — no connections, file reads, or network calls, so
tests can import without a live environment.

## Typing

Annotate every parameter and return. Builtin generics only — `list[dict]`,
`X | None`. Never `List`, `Dict`, `Optional`, `Union`. If the default is `None`,
say so: `list[str] | None = None`.

## Classes and functions

Abstract on the **second** implementation, not the first.

**Pydantic for structured data** — boundaries and most internal structs.
`@dataclass` only when validation is unwanted. On v2: `@field_validator`,
`@model_validator`; `@validator` and `@root_validator` are deprecated. Validate
with a model, never a wall of `isinstance` checks.

**Function parameter over subclass when one step varies:**

```python
def sync_source(
    name: str,
    extract_method: Callable = extract,
    load_method: Callable = load_full_refresh,
) -> None:
```

Class hierarchies are for when several methods vary together and share state.

**The base owns the shared work; a child declares what it *is*.** Ordering,
joins, key derivation, normalization go on the base; a child supplies field
values and overrides only what varies, usually I/O. Shared logic outside the
hierarchy means adding an implementation edits that outside code too.

**Child class over configured instance** once differences are declarative.
`LegacySource(name="legacy", numeric_ids=True, …)` buries facts in an argument
list; typed field defaults on a subclass are greppable and checkable.

**Wrong base if the candidate inherits fields it must leave empty and overrides
every method.** Hang it one level up. Sharing a *contract* is not being a
subtype.

**A fixed order of operations deserves its own class** — the sequence is the part
most easily got wrong, and stated once it can be read in one place.

**Collaborators in `__init__` with production defaults**, so tests pass stubs
instead of patching globals:

```python
def __init__(self, reconciler: Reconciler | None = None, store: Store | None = None):
    self._reconciler = reconciler or Reconciler()
    self._store = store or Store()
```

Set every attribute in `__init__`; skip an `__init__` that only calls `pass`.
`@property` for derived values, `@cached_property` when expensive and inputs are
fixed, `@staticmethod` for stateless helpers, `@classmethod` for alternative
constructors.

## Encapsulation

**Budget the public surface and measure it.** One package exported 114 public
names against the 12 its only caller used — the other 102 were internals a future
caller could reach for. Past ~2× means the internals have leaked.

**Format knowledge lives in the object that owns the format.** Grep a magic
string — CSV column, payload key — and it should appear in exactly one module.

**Public is what a thing *is*; private is what it *does*.** Declared config
(precedence, paths, dtypes, flags a subclass sets) is data about the object and
is public. The mechanics consuming it — validating, coercing, ordering, building
the query — are not.

**One entry point per concern.** `source.curate(path, filters)`, not five
exported functions the caller must sequence. If callers sequence your internals,
that sequence is the abstraction you failed to write.

**Don't re-export a subpackage flat.** An `__init__` importing 25 names from four
modules published four modules, not one package.

**Group loose constants into a named class** — `DocumentRow.ALL`. Four constants
that always travel together are an unnamed object.

**Declare `__all__` and assert it in a test** ([references/testing.md](references/testing.md)).
Convention alone doesn't hold against the next `from x import *`.

## Language traps

No linter catches these.

**Pydantic v2 makes leading-underscore attributes private attrs, not fields.**
`_numeric_ids: bool = False` is unsettable and `Model(_numeric_ids=True)` raises.
Declared config must be public-named; `PrivateAttr` only for genuine internals.

**A comprehension in a class body can't see class variables** — only the first
iterable is evaluated in class scope:

```python
class Row:
    LIFECYCLE = ("a", "b")
    CURATION = [c for c in ALL if c not in LIFECYCLE]   # NameError
```

Compute at module level, expose through the class.

**On a frozen dataclass, an unannotated attribute is a constant, not a field.**
`UNDATED = "undated"` is class-level; `undated: str = "x"` joins `__init__` and
`__eq__`.

**`pandas.read_parquet(columns=[...])` drops a missing column silently** — a
renamed upstream field looks identical to every row being empty. General rule:
when a library's "not found" is indistinguishable from "empty", assert presence
yourself.

## Config and constants

No credentials, magic numbers, or query strings inside a class. Limits, delays,
page sizes, model names, and paths are config — a cap buried in a constructor
truncates results with nothing in its name to warn you.

One typed object from defaults, env vars, and `.env` via `pydantic.BaseSettings`;
commit `.env.example` with every key. `Enum` for a fixed set of choices — bare
strings can't be checked exhaustively.

**Secrets by name, never by value.** Keep the identifier — env var, vault path,
secret name — and resolve at runtime.

## Errors

**Catch narrow, log with `exc_info=True`, re-raise.** The dangerous failure
returns a plausible value:

```python
# no — an outage and "no matches" are now indistinguishable
except Exception as e:
    logging.error(f"Error: {e}")
    return []
```

An empty list means "nothing matched". If the call never ran, let it propagate. A
context manager that swallows a failure and yields `None` is the same bug.

**Batch work accumulates, then raises:**

```python
error_count = 0
for item in items:
    try:
        process(item)
    except ProcessingError as e:
        error_count += 1
        logger.error(f"Failed on {item}: {e}", exc_info=True)

if error_count:
    raise BatchError(f"{error_count} of {len(items)} items failed")
```

The final `raise` is the point — without it this is swallowing.

Retry transient failures only, capped exponential backoff. Never retry a client
error.

## Logging

`logging`, never `print` — different destinations once something else runs the
process, and no level filtering. Use a framework's run-scoped logger where there
is one.

Log at boundaries (start, end, failure, state advance), not in loops. Log
traceable identifiers: source, run id, counts. Never secrets or personal data.

## Comments and docstrings

Google style, and the docstring must be the **first statement inside** the
function or class — a string above `class` or `def` is discarded, invisible to
`help()` and IDEs. `Args:` and `Returns:` when non-obvious, `Raises:` whenever
the caller must handle it.

Greppable tags: `# INFO:` (context needed to not break this), `# NOTE:` (a
surprising deliberate choice), `# TODO:` (actionable gap).

Comments explain *why*. `# init`, `# set path` are noise. Section separators at
one width per repo; needing many means the module should split.

## State and reprocessing

Rerunnable work must be idempotent — upsert on a natural key or replace the
partition, never bare-append. Persist progress markers outside the process,
advance only after the write succeeds, and stamp records with extraction and load
timestamps.

**Give partial updates their own write path.** A pipeline whose only write is a
full replacement forces a total re-run to fix one column, discarding every
derived artifact. Add the narrow `ON CONFLICT DO UPDATE` over just the changing
columns, and skip rows that don't exist rather than inserting stubs — a stub
answers "this table needs rebuilding" with a broken row.

**Separate regenerable from irreplaceable data, in code.** Before writing a
rebuild flow, ask which output columns a machine can reproduce. Anything a human
typed is carried forward on a stable key, and the flow **refuses** rather than
emitting blanks — blank review marks read as "nothing selected", not as data
loss. One sheet held 66,239 hand-entered marks; a naive regenerate would have
destroyed all of them silently.

**Validate a key on the whole domain, not the current slice.** A field unique in
today's filtered scope may not be unique at large — one document number named 84
unrelated records once the filter widened. Measure distinctness on the full
dataset, and never add a `UNIQUE` constraint that only holds because of a `WHERE`
clause elsewhere.

## Files

`pathlib.Path` over `os.path` — `Path("data") / name`, `path.read_text()`.

## Tests

`pytest` only. Name `test_<what>_<condition>_<expected>`, mark by cost, record
HTTP rather than calling live APIs — mask credentials before the first recording,
since cassettes are committed. See [references/testing.md](references/testing.md).

## Before committing

- `ruff format` and `ruff check --fix` clean
- Every parameter and return annotated
- No `print`, no bare `except Exception` that returns a value
- No credentials, magic numbers, or absolute paths in code
- `Raises:` documented where the caller must handle it
- Rerunnable work is idempotent
- Nothing public that an outside caller doesn't need
- No external format's field names visible outside the class that reads it
- Collaborators injectable, so no test patches a module global
- Test count went **up** — read the number, not just the colour
