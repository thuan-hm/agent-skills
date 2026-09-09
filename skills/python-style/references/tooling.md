# Repo tooling

Config lives in `pyproject.toml` wherever a tool allows it.

## Toolchain

`uv` for environments, dependencies, locking, running. `ruff` for lint and
format. `mypy` at boundaries and in shared libraries. `just` for task recipes.

Pin the interpreter with `requires-python = "==3.12.*"` and a committed
`.python-version`. Commit `uv.lock`.

## Ruff

Start with `select = ["F", "I"]` — undefined names, unused imports, import order.
Add rules once the codebase is clean:

| Rule | Catches |
|---|---|
| `UP` | `List[Dict]` where `list[dict]` belongs |
| `B` | mutable default args, broad `except` |
| `N` | `camelCase` functions and modules |
| `T20` | `print()`; exempt entrypoints and DAGs |
| `PTH` | `os.path` where `pathlib` belongs |
| `ANN` | missing parameter and return annotations |
| `PT` | pytest fixture and `parametrize` style |

Enabling everything at once on an existing repo produces thousands of findings
and gets switched off the same day.

Exclude `.venv`, notebooks, generated dirs, vendored SQL.

## Pre-commit

Pin every hook to a `rev`.

| Hook | Prevents |
|---|---|
| `gitleaks`, `detect-private-key` | a committed secret — public the moment it's pushed |
| `ruff`, `ruff-format` | style noise in review |
| `codespell` | typos in identifiers and comments |
| `check-json`, `check-yaml`, `check-merge-conflict` | a broken config reaching CI |
| `trailing-whitespace` | whitespace-only diffs |
| `autoflake` | unused imports and variables |

## .editorconfig

Settles indentation at the editor, before any formatter runs.

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

In an existing repo, match its `.editorconfig` even where it disagrees with this.

## Dependencies

Pin by fragility:

| Form | Use for |
|---|---|
| `==` | libraries that break on patch releases — data and serialization layers |
| `>=x,<y` | frameworks tracked deliberately; the upper bound stops an unannounced major |
| `>=` | stable utilities |

Split groups by purpose: `dev` for local work, `ci` for the subset the runner
needs.

Comment a load-bearing pin with what breaks if it moves, and back it with a
version test.

## Mypy

```toml
[tool.mypy]
warn_return_any = true
warn_unused_configs = true
ignore_missing_imports = true
plugins = "pydantic.mypy"
```

The Pydantic plugin is what makes model fields check.

## Justfile

```make
lint path:
    uv run ruff check {{path}} --fix

type_check path:
    uv run mypy {{path}}

test:
    uv run pytest -m unit
```
