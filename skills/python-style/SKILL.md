---
name: python-style
description: House Python conventions — naming, imports, typing, class design, config, error handling, logging, comments, and tests. Use when writing or reviewing any Python in my projects, starting a new repo, adding a module or service, or on phrasings like "review this code", "structure this project", "set up ruff", "is this pythonic".
---

# Python style

Conventions that tooling can't enforce. Everything mechanical — spacing, import
order, quote style, line length — is `ruff`'s job.

- Repo setup — ruff, pre-commit, pinning, mypy: [references/tooling.md](references/tooling.md)
- Testing: [references/testing.md](references/testing.md)
- Project skeletons: [references/layouts.md](references/layouts.md)
- Drop-in config: [references/pyproject-template.toml](references/pyproject-template.toml)

## Naming

| Kind | Form | Example |
|---|---|---|
| module, function, variable | `snake_case` | `api_client.py`, `fetch_page` |
| class | `PascalCase` | `BaseFetcher` |
| module constant | `SCREAMING_CASE` | `DEFAULT_PAGE_SIZE` |
| internal attr / method | `_leading` | `self._client`, `_build_query()` |
| subclass-collision guard | `__leading` | `self.__buffer` |

Acronyms follow the rule of the surrounding name, so `http_client.py` and
`api_io.py` — never `httpClient.py` or `apiIO.py`.

**`_single` is the default for internals** — it signals intent, linters enforce
it, and subclasses and tests can still reach it.

**`__double` is the rare, deliberate case.** It triggers name mangling — `__buffer`
inside `Loader` becomes `_Loader__buffer` — so a subclass silently gets a
*different* attribute instead of overriding, and tests must spell the mangled
name. Use it only when a base class holds state subclasses must not touch, and
say why in a comment.

Names carry units and intent: `max_requests_per_run` over `max_requests`,
`fetched_at` over `date`, `timeout_seconds` over `timeout`.

## Imports

Absolute, from the package root — `from mypkg.lib.config import Config`. Relative
imports break the moment a module moves and hide where a name actually lives.

No side effects at import time. Importing a module must not open connections,
read files, or make network calls; put that behind a function or a lazy property
so a test can import without a live environment.

## Typing

Annotate every parameter and return. Builtin generics only — `list[dict]`,
`dict[str, int]` — and `X | None` over `Optional[X]`. Never `List`, `Dict`,
`Tuple`, `Union`. If the default is `None` the annotation says so:
`list[str] | None = None`, never `list = None`.

## Classes and functions

Reach for an abstraction on the **second** implementation, not the first.

**Pydantic is the default for structured data** — anything crossing a boundary
(request, response, config, external payload) and most internal structs too.
`@dataclass` only where a model would be overkill and no validation is wanted.
On Pydantic v2 use `@field_validator` and `@model_validator`; `@validator` and
`@root_validator` are deprecated.

**ABC + `@abstractmethod`** when several implementations share a lifecycle — one
module each, dispatch on the base.

**Prefer a function parameter to a subclass when only one step varies.** A
generic routine taking `Callable` steps with sensible defaults covers a new case
without a new class:

```python
def sync_source(
    name: str,
    extract_method: Callable = extract,
    transform_method: Callable = transform,
    load_method: Callable = load_full_refresh,
) -> None:
```

Each entrypoint is then a thin caller that swaps the one step it needs. Class
hierarchies are for when several methods vary together and share state.

Use `@property` for derived values, `@cached_property` when the derivation is
expensive and the inputs are fixed, `@staticmethod` for helpers touching no
state, `@classmethod` for alternative constructors.

Set every attribute in `__init__`, and skip an `__init__` that only calls `pass`.
An attribute created partway through some other method makes the class
order-dependent.

**Validate with Pydantic, never a wall of `isinstance` checks** — hand-rolled
checks are long and their messages drift out of sync with the parameters they
describe.

## Config and constants

No credentials, magic numbers, or query strings inside a class. Limits, retry
delays, page sizes, model names, and paths are config: they change without a code
change, and a cap buried in a constructor silently truncates results with nothing
in its name to warn you.

Merge defaults, env vars, and `.env` into one typed object with
`pydantic.BaseSettings`, and commit a `.env.example` listing every key with dummy
values.

Group non-secret constants into named classes in one module, so a limit or field
name has exactly one home and reads as `Constants.MAX_PAGE_SIZE`. Use `Enum` for
a fixed set of choices — a class of bare strings can't be checked exhaustively.

**Reference secrets by name, never by value.** Keep the credential's *identifier*
in code — env var, vault path, secret name — and resolve the value at runtime.
Code stays committable and rotation touches nothing.

## Errors

**Catch narrow, log with context, re-raise.** The dangerous failure is the one
that returns a plausible value:

```python
# no — an outage and "no matches" are now indistinguishable
except Exception as e:
    logging.error(f"Error: {e}")
    return []
```

An empty list means "nothing matched". If the call never ran, let it propagate.
A context manager that swallows a connection failure and yields `None` is the
same bug in different clothing.

Always log with `exc_info=True`. Without it you keep the message and lose the
traceback, which is the half that says where it happened.

**Batch work is the exception to fail-fast: accumulate, then raise.** One bad
item shouldn't strand the other nine, but the run must still fail loudly:

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

The final `raise` is the whole point — without it this is just swallowing.

Retry only transient failures with capped exponential backoff. Never retry a
client error; the request is wrong and stays wrong.

## Logging

`logging`, never `print`. They don't land in the same place once something else
is running the process, and `print` can't be filtered by level. Where a framework
supplies a run-scoped logger, use it so lines attach to the run.

Log at boundaries — start, end, failure, state advance — not inside loops. Log
the identifiers that let you trace one execution: source, run id, counts. Never
log secrets, tokens, or personal data.

## Comments and docstrings

Google-style docstrings, and the docstring must be the **first statement inside**
the function or class. A string above a `class` or `def` is a discarded
expression — invisible to `help()`, IDEs, and doc tooling.

Document `Args:` and `Returns:` on anything non-obvious, and `Raises:` whenever
the caller must handle a failure.

Tag comments that carry weight so they're greppable:

- `# INFO:` — context the reader needs to not break this
- `# NOTE:` — a deliberate, surprising choice
- `# TODO:` — known gap, with enough detail to act on

Comments explain *why*. Anything that restates the code (`# init`, `# set path`)
is noise. Section separators are fine at one width per repo; a module needing
many of them is asking to be split.

## State and reprocessing

Any job that can rerun must be idempotent — rerunning must not duplicate rows or
double-apply an effect. Upsert on a natural key or replace the partition; never
bare-append.

Persist progress markers outside the process, advance them only after the write
succeeds, and make each step resumable from its last marker. Stamp loaded records
with extraction and load timestamps — freshness and lineage are the first two
questions when a number looks wrong later.

## Files

`pathlib.Path` over `os.path` — `Path("data") / name`, `path.read_text()`. It
composes and it's OS-independent.

## Tests

`pytest` only. Name tests `test_<what>_<condition>_<expected>`, mark them by cost,
and test against recorded HTTP rather than live APIs — masking credentials before
the first recording, since cassettes are committed files. See
[references/testing.md](references/testing.md).

## Before committing

- `ruff format` and `ruff check --fix` clean
- Every parameter and return annotated
- No `print`, no bare `except Exception` that returns a value
- No credentials, magic numbers, or absolute paths in code
- `Raises:` documented where the caller must handle it
- Rerunnable work is idempotent
