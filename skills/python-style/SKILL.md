---
name: python-style
description: House Python conventions — naming, imports, typing, class design, encapsulation, config, error handling, logging, comments, state, and tests. Use when writing or reviewing any Python in my projects, starting a new repo, adding a module or service, or on phrasings like "review this code", "structure this project", "set up ruff", "is this pythonic".
---

# Python style

Conventions tooling can't enforce. Spacing, import order, quote style, and line
length are `ruff`'s job.

- Layout: [references/layouts.md](references/layouts.md)
- Repo setup: [references/tooling.md](references/tooling.md)
- Testing: [references/testing.md](references/testing.md)
- Config template: [references/pyproject-template.toml](references/pyproject-template.toml)

## Naming

| Kind | Form | Example |
|---|---|---|
| module, function, variable | `snake_case` | `api_client.py`, `fetch_page` |
| class | `PascalCase` | `BaseFetcher` |
| module constant | `SCREAMING_CASE` | `DEFAULT_PAGE_SIZE` |
| internal attr / method | `_leading` | `self._client`, `_build_query()` |
| subclass-collision guard | `__leading` | `self.__buffer` |

Acronyms follow the surrounding name: `http_client.py`, `api_io.py`.

`_single` is the default for internals. `__double` mangles — `__buffer` in
`Loader` becomes `_Loader__buffer`, so a subclass gets a different attribute
instead of overriding. Use it only to protect base-class state, with a comment
saying why.

Names carry units and intent: `max_requests_per_run`, `fetched_at`,
`timeout_seconds`.

## Imports

Absolute from the package root: `from mypkg.lib.config import Config`.

No side effects at import time — no connections, file reads, or network calls.

## Typing

Annotate every parameter and return. Builtin generics only: `list[dict]`,
`X | None`. Never `List`, `Dict`, `Optional`, `Union`. If the default is `None`,
annotate it: `list[str] | None = None`.

## Classes and functions

Abstract on the second implementation, not the first.

**Pydantic for structured data** — boundaries and most internal structs.
`@dataclass` only when validation is unwanted. On v2 use `@field_validator` and
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

Use a class hierarchy when several methods vary together and share state.

**The base owns shared work; a child declares what it is.** Ordering, joins, key
derivation, and normalization go on the base. A child supplies field values and
overrides only what varies, usually I/O.

**Child class over configured instance** once differences are declarative. Typed
field defaults on a subclass are greppable and checkable; a long argument list
is not.

**Wrong base if the candidate inherits fields it leaves empty and overrides every
method.** Hang it one level up. Sharing a contract is not being a subtype.

**A fixed order of operations gets its own class** — stated once, read in one
place.

**Collaborators in `__init__` with production defaults**, so tests pass stubs
instead of patching globals:

```python
def __init__(self, reconciler: Reconciler | None = None, store: Store | None = None):
    self._reconciler = reconciler or Reconciler()
    self._store = store or Store()
```

Set every attribute in `__init__`. Skip an `__init__` that only calls `pass`.
`@property` for derived values, `@cached_property` when expensive with fixed
inputs, `@staticmethod` for stateless helpers, `@classmethod` for alternative
constructors.

## Encapsulation

**Export what callers need, nothing more.** Count exported names against the
names consumers import; a large gap means internals leaked.

**Format knowledge lives in the object that owns the format.** Grep any magic
string — CSV column, payload key, layout quirk — and it appears in one module.

**Public is what a thing is; private is what it does.** Declared configuration —
precedence, paths, dtypes, flags a subclass sets — is public. The mechanics that
consume it — validating, coercing, ordering, query building — are not.

**One entry point per concern.** `source.curate(path, filters)`, not five
exported functions the caller sequences. A sequence callers must reproduce is a
missing abstraction.

**Don't re-export a subpackage flat.** An `__init__` importing every name from
four modules published four modules, not one package.

**Group loose constants into a named class**: `DocumentRow.ALL`. Constants that
travel together are an unnamed object.

**Declare `__all__` and assert it in a test** ([references/testing.md](references/testing.md)).

## Language traps

**Pydantic v2 treats leading-underscore attributes as private attrs, not
fields.** `_numeric_ids: bool = False` can't be set through the constructor and
`Model(_numeric_ids=True)` raises. Declared config must be public-named; use
`PrivateAttr` for genuine internal state.

**A comprehension in a class body can't see class variables.** Only the outermost
iterable is evaluated in class scope:

```python
class Row:
    LIFECYCLE = ("a", "b")
    CURATION = [c for c in ALL if c not in LIFECYCLE]   # NameError
```

Compute at module level, expose through the class.

**On a dataclass, an unannotated class attribute is not a field.**
`UNDATED = "undated"` is a plain class attribute; `undated: str = "x"` joins
`__init__`, `__eq__`, and `repr`.

**When a library's "not found" is indistinguishable from "empty", assert presence
yourself.** A narrowing read selecting a column subset can yield nothing rather
than raise when a field is renamed upstream. Check expected columns before
trusting the result.

## Config and constants

No credentials, magic numbers, or query strings inside a class. Limits, delays,
page sizes, model names, and paths are config.

One typed object from defaults, env vars, and `.env` via `pydantic.BaseSettings`.
Commit `.env.example` with every key. `Enum` for a fixed set of choices.

**Secrets by name, never by value.** Keep the identifier — env var, vault path,
secret name — in code; resolve the value at runtime.

## Errors

**Catch narrow, log with `exc_info=True`, re-raise.**

```python
# no — an outage and "no matches" are now indistinguishable
except Exception as e:
    logging.error(f"Error: {e}")
    return []
```

An empty list means "nothing matched". If the call never ran, let it propagate.
A context manager that swallows a connection failure and yields `None` is the
same bug.

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

Without the final `raise` this is swallowing.

Retry transient failures only, with capped exponential backoff. Never retry a
client error.

## Logging

`logging`, never `print`. Use a framework's run-scoped logger where there is one.

Log at boundaries — start, end, failure, state advance — not inside loops. Log
source, run id, and counts. Never log secrets, tokens, or personal data.

## Comments and docstrings

Google style. The docstring is the **first statement inside** the function or
class; a string above `class` or `def` is discarded and invisible to `help()`.
`Args:` and `Returns:` when non-obvious, `Raises:` whenever the caller must
handle a failure.

Greppable tags: `# INFO:` context needed to not break this, `# NOTE:` a
surprising deliberate choice, `# TODO:` an actionable gap.

Comments explain why. `# init`, `# set path` are noise. Section separators at one
width per repo.

## State and reprocessing

Rerunnable work must be idempotent: upsert on a natural key or replace the
partition, never bare-append. Persist progress markers outside the process,
advance them only after the write succeeds, and stamp records with extraction and
load timestamps.

**Give partial updates their own write path.** When the only write is a full
replacement, fixing one column costs a total re-run and discards derived
artifacts. Add a narrow `ON CONFLICT DO UPDATE` over the changing columns, and
skip rows that don't exist rather than inserting stubs.

**Separate regenerable data from irreplaceable data, in code.** Before writing a
rebuild path, identify which output columns a machine can reproduce. Carry
human-entered values forward on a stable key, and **refuse** rather than emit
blanks when they can't be found — a blank reads as "nothing was set", so the loss
is silent.

**Validate a key against the whole domain, not the current slice.** A field
unique in a filtered scope may collide once the filter widens. Measure
distinctness on the full dataset, and never add a `UNIQUE` constraint that holds
only because of a `WHERE` clause elsewhere.

## Files

`pathlib.Path` over `os.path`: `Path("data") / name`, `path.read_text()`.

## Tests

`pytest` only. Name `test_<what>_<condition>_<expected>`, mark by cost, record
HTTP instead of calling live APIs, mask credentials before the first recording.
See [references/testing.md](references/testing.md).

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
- Test count went up — read the number, not just the colour
