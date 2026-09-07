# Testing

`pytest` only, no `unittest`.

## Naming and shape

Name tests `test_<what>_<condition>_<expected>`, so a failure in CI output reads
as a sentence and you know what broke without opening the file.

Fixtures over setup methods. `@pytest.mark.parametrize` for variations of the
same assertion. `tmp_path` for anything touching the filesystem — never a
hardcoded temp dir, never the repo tree.

## Mark by cost

```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py", "*_test.py"]
markers = [
  "unit: fast, isolated",
  "integration: crosses a boundary",
  "slow: long running",
  "smoke: quick post-deploy validation",
]
```

Declaring markers silences `PytestUnknownMarkWarning` and makes the vocabulary
explicit. CI then runs `-m unit` on every push and the full suite on merge.

`pytest-xdist` for parallelism, `pytest-cov` for coverage.

## Record HTTP, don't call it

Test against recorded responses with `pytest-recording`/VCR: record once, replay
after. The suite becomes fast, offline, and deterministic, and it stops being a
way to burn API quota.

**Configure filtering before the first recording.** A cassette is a committed
file, so an unmasked one is a leaked credential:

```python
VCR_FILTER_HEADERS = ["Authorization", "Cookie", "Set-Cookie", "user-agent"]
VCR_FILTER_POST_DATA_PARAMETERS = [
    ("api_key", "MASKED"),
    ("secret", "MASKED"),
    ("refresh_token", "MASKED"),
    ("client_id", "MASKED"),
    ("client_secret", "MASKED"),
]
```

Re-record deliberately, and read the diff before committing it.

## Two cheap tests worth having anywhere

- **Import test** — import every module in the package. Catches a broken import or a circular dependency before deploy, and costs one file.
- **Version compatibility test** — when a framework is pinned to a narrow range, assert the installed version falls inside it. The pin and the assumption then fail together, loudly, instead of drifting apart.
