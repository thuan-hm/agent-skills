# Project layouts

Three skeletons. Take the one that matches the work; they compose when a repo
does more than one thing. The shared rules: `src/` layout, one package per
responsibility, entrypoints hold no logic, notebooks stay out of the import path.

## Ingestion / ETL

Split by *stage*, so a new source means one new module per stage and no edits
elsewhere.

```text
src/
  ingestion/
    scrapers/          # fetch raw — one module per source
    normalizers/       # raw → common shape
    transformers/      # common shape → warehouse rows
    state/             # checkpoints, watermarks
  <store_a>/           # connection.py, session.py, data_access.py
  <store_b>/           # same triad, one package per backend, named for it
  runners/             # thin entrypoints
pipelines/dags/        # orchestration only; imports from src/
sql/
  00_init/             # schemas, extensions, roles
  core/                # ddl.sql, view.sql, index.sql
tests/
```

Base class per stage (`BaseScraper`, `BaseNormalizer`), one implementation per
source. The runner picks an implementation and calls the shared interface.

## Orchestrated pipelines

When an orchestrator owns execution, split the same
work into four layers by how reusable each is:

```text
etl/
  flows/      # one per scheduled job — thin: pick inputs, call a template
  templates/  # generic parameterized job, swappable extract/transform/load
  tasks/      # the units of work, grouped per source
  lib/        # shared — config.py, constants.py, settings.py, connectors/, utils/
```

The payoff is that adding a source touches `tasks/` and adds one small file in
`flows/`, while the orchestration logic in `templates/` is written once. A flow
that grows its own extract logic is a template asking to be written.

Give each flow an `if __name__ == "__main__":` block with an argument parser, so
it runs standalone without the scheduler.

## ML / AI

The boundary that matters is config ↔ logic ↔ I/O. Keep experiments
reproducible: pin dependencies, externalize every hyperparameter, version data
and models by reference.

```text
src/
  data/                # loading, splitting, feature building
  models/              # architecture / estimator definitions
  training/            # train loop, evaluation, checkpointing
  inference/           # predict path, batch and online
  config/              # Pydantic BaseSettings + YAML defaults
notebooks/             # exploration only — findings graduate into src/
configs/               # experiment YAMLs, one per run variant
tests/
```

No hyperparameter in code. An experiment is a config file plus a commit, so a
run is reproducible from those two facts alone.

## Backend service

```text
backend/
  api/v1/
    routers/           # HTTP only — parse, delegate, return
    services/          # business logic
    schemas/           # Pydantic request/response
    models/            # ORM
  core/                # settings, logging setup, dependencies
  main.py              # app assembly only
tests/
```

Routers stay thin. A router that reaches past its service into the ORM is the
first crack — once HTTP concerns and query logic mix, neither can be tested
alone.

## Repo root, any of the above

```text
pyproject.toml         # single source of truth for tooling
.env.example           # every key, dummy values
docker-compose.yml     # plus .dev / .prod overrides
Dockerfile             # per deployable service
.github/workflows/     # ci.yml, cd.yml
README.md
```
