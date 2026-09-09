# Project layout

No single structure fits every project. Set clear boundaries, then group code by
what changes together. This is a baseline to cut down, not a tree to fill in.

```text
project/
├── src/
│   └── <package>/
│       ├── sources/           # read from external systems
│       ├── transforms/        # business rules on data
│       ├── loaders/           # writes to stores
│       ├── pipelines/         # compose source → transform → load
│       ├── config/            # config loading and validation
│       ├── observability.py   # logging setup
│       └── errors.py          # domain exceptions
│
├── orchestration/
│   ├── flows/                 # one per scheduled job; thin
│   └── tasks/                 # orchestrator-specific definitions
│
├── sql/                       # staging/ intermediate/ marts/ if using dbt
├── environments/              # per-environment values (dev.yaml, prod.yaml)
├── tests/                     # conftest.py, unit/, integration/
├── notebooks/                 # exploration only
├── scripts/                   # operational commands
│
├── pyproject.toml             # deps + tool config
├── uv.lock
├── .python-version
├── .pre-commit-config.yaml
├── .editorconfig
├── .env.example
├── justfile
├── Dockerfile
├── .github/workflows/
└── README.md
```

`config/` holds the code that loads settings; `environments/` holds the values.
Not `config/` beside `configs/` — one letter apart, different meanings.

`errors` and `observability` start as modules. Three exception classes and a
`configure_logging()` don't earn a package.

The tooling files are part of the layout.

## Responsibilities

```text
orchestration → pipelines → sources → transforms → loaders
```

Nothing imports upward. A transform importing from `pipelines/`, or a source
importing a loader, has inverted the arrow.

**`sources/`** — one module per external system. Owns auth, pagination, cursors,
incremental extraction. No downstream business logic.

**`transforms/`** — plain functions, no I/O, deterministic.

**`loaders/`** — one module per destination. **Loaders own idempotency**: the
orchestrator retries, and only the loader makes a second write safe. Upsert on a
natural key or replace the partition, never bare-append.

**`pipelines/`** — what the workflow does, never when it runs. Dependencies
arrive through `__init__`:

```python
class CustomerSync:
    def __init__(self, source: Source, loader: Loader) -> None:
        self.source = source
        self.loader = loader

    def run(self, watermark: str | None) -> None:
        records = self.source.fetch(watermark)
        self.loader.upsert(normalize_customers(records))
```

**`orchestration/`** — scheduling, retries, dependencies, run parameters. Flows
call a pipeline and nothing else. Switching orchestrators must not require
rewriting anything under `src/`. Give each flow an `if __name__ == "__main__":`
with an argument parser so it runs standalone.

**`config/`** — one typed object from defaults, env vars, and files, validated at
startup so a missing key fails immediately. Secrets resolve at runtime from their
identifier.

**`observability.py`** — configure logging once at the application boundary.
Modules obtain a logger; they never configure globally.

**`errors.py`** — a hierarchy so callers can distinguish failures: retry
`SourceError`, let `SchemaMismatchError` through. Lower layers raise;
orchestration decides retry, skip, or fail.

## Choosing the axis

Structure follows the main axis of change. Source-specific behaviour dominating
means grouping by source — `sources/github/{extract,normalize,schema}.py`. Shared
transformations mean grouping by stage — `sources/github.py` plus
`transforms/customers.py`.

The test:

> When adding a source or changing a requirement, how many unrelated modules
> need to change?

**Split by stage only while stages differ per source.** Once several stages are
identical for everything — same normalization, same key derivation — a
stage-per-package layout scatters one source across four packages and forces an
edit in each to add a fifth. Split by question instead, with shared work on the
base:

```text
ingestion/
  identity.py    # what makes two records the same record
  schema.py      # the columns of a stored row
  curation/      # which records we WANT
  sources/       # where records COME FROM — base + one class per source
  workflows.py   # the orders of operations
  merge.py       # cross-source reconciliation
  load.py        # the writes
```

Either way, dispatch through a **registry** — a dict of name to implementation
with a `get(name)` that raises on an unknown key. No `if`/`elif` on strings, no
source name spelled outside it. Adding a source is one class and one entry.

## Modules and classes

Don't create a class to group a function. Use one for meaningful state,
configuration, lifecycle, or polymorphism. Prefer composition.

`Protocol` for a narrow interface with no shared implementation — no base class,
no import from the implementations:

```python
class Source(Protocol):
    def fetch(self, watermark: str | None) -> list[dict]: ...
```

ABC when implementations share code or a lifecycle and the base gives them
something beyond a signature. No factory or plugin system until runtime
substitution requires it.

Declare `__all__` in `__init__.py`. Without it every module is public by accident.

## Utilities

No generic `utils/`, `common/`, or `helpers/`. Reusable code gets a real owner —
`storage/paths.py`, `serialization/json.py`, `infrastructure/retry.py`. A helper
used by one domain stays with that domain.

The failure mode is a name that stops excluding things. `utils/`, `core/`, and
`document/` accept any file, so unrelated things accrete. If two files under a
package aren't obviously about the thing it names, put them at the package root
and let each name work.

## Notebooks and tests

Notebooks explore; stable logic moves into `src/`. Keep them out of the import
path and excluded from lint and type checking. Production never depends on
notebook execution.

Tests mirror the boundaries that matter: `conftest.py` for shared fixtures,
`unit/` and `integration/` split by cost, marked so CI can run the fast set.

## Variants

**ML / AI** — the boundary is config ↔ logic ↔ I/O:

```text
src/<package>/
  data/         # loading, splitting, features
  models/       # architecture / estimator definitions
  training/     # train loop, evaluation, checkpointing
  inference/    # predict path
configs/        # one YAML per experiment variant
```

No hyperparameter in code. An experiment is a config file plus a commit.

**Backend service** — routers stay thin:

```text
backend/api/v1/
  routers/      # HTTP only — parse, delegate, return
  services/     # business logic
  schemas/      # Pydantic request/response
  models/       # ORM
backend/core/   # settings, logging, dependencies
backend/main.py # app assembly only
```

A router reaching past its service into the ORM mixes HTTP concerns with query
logic, and neither can then be tested alone.

## Start smaller

A small ingestion job needs:

```text
src/project/{source,transform,load}.py
tests/
pyproject.toml
README.md
```

Add packages when responsibilities and change boundaries become clear. The goal
is making responsibilities, dependencies, and change boundaries obvious — not
more directories.
