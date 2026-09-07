# Repo tooling

What to set up once so the mechanical rules enforce themselves. Config lives in
`pyproject.toml` wherever a tool allows it — one file, one source of truth.

## Toolchain

`uv` for environments, dependencies, locking, and running. `ruff` for lint and
format. `mypy` where types are load-bearing. `just` for task recipes.

Pin the interpreter — `requires-python = "==3.12.*"` plus a committed
`.python-version` — and commit `uv.lock`. An unpinned interpreter is the most
common "works on my machine".

## Ruff: start narrow

Begin with `select = ["F", "I"]` — undefined names, unused imports, import order.
That's the set that catches real bugs and never argues about taste, so nobody
disables it. Add rules deliberately once the codebase is clean:

| Add | Buys you |
|---|---|
| `UP` | `list[dict]` over `List[Dict]`, modern syntax |
| `B` | mutable default args, broad `except` |
| `N` | catches `camelCase` functions and modules |
| `T20` | bans `print()`; exempt entrypoints and DAGs |
| `PTH` | `pathlib` over `os.path` |
| `ANN` | annotations on every parameter and return |
| `PT` | pytest fixture and `parametrize` style |

Enabling everything at once on an existing repo produces thousands of findings
and gets switched off the same day. A narrow set that stays on beats a broad set
that gets deleted.

Exclude what isn't yours: `.venv`, notebooks, generated dirs, vendored SQL.

## Pre-commit

The hooks that earn their runtime, roughly in order of value:

- **`gitleaks`** and **`detect-private-key`** — the only hooks that prevent an unfixable mistake. A committed secret is public the moment it's pushed; rotating it is the *cheap* outcome.
- **`ruff`** (`--fix`) and **`ruff-format`** — mechanical style, settled before review.
- **`codespell`** — typos in identifiers and comments outlive everything.
- **`check-json`**, **`check-yaml`**, **`check-merge-conflict`**, **`trailing-whitespace`** — cheap, catch a broken config before CI does.
- **`autoflake`** — strips unused imports and variables.

Pin every hook to a `rev`. Unpinned hooks change behavior underneath you.

## .editorconfig

Commit one. It settles indentation at the editor, before any formatter runs, and
it's the actual fix for a repo that drifts between 2-space and 4-space files.

```ini
root = true

[*]
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true

[*.py]
indent_style = space
indent_size = 4
```

When joining an existing repo, match its `.editorconfig` even where it disagrees
with this — one consistent file beats a correct one that fights its neighbours.

## Dependencies

Pin by fragility, not uniformly:

- **Exact (`==`)** for libraries that break on patch releases — data and serialization layers especially, where a minor bump changes dtypes or file formats.
- **Range with an upper bound (`>=x,<y`)** for frameworks you track deliberately. The upper bound is the point: it stops a major release from landing unannounced.
- **Floor only (`>=`)** for stable, well-behaved utilities.

Split groups by purpose — `dev` for local work, `ci` for the subset the runner
needs. CI installs less and starts faster.

When a pin is load-bearing, leave a comment saying what breaks if it moves, and
back it with a version test.

## Mypy

Worth it at boundaries and in shared libraries; skip it in exploratory code.

```toml
[tool.mypy]
warn_return_any = true
warn_unused_configs = true
ignore_missing_imports = true
plugins = "pydantic.mypy"
```

The Pydantic plugin is what makes model fields actually check.

## Justfile

One entrypoint per routine task, so nobody memorizes flags:

```make
lint path:
    uv run ruff check {{path}} --fix

type_check path:
    uv run mypy {{path}}

test:
    uv run pytest -m unit
```
