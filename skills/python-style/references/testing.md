# Testing

`pytest` only, no `unittest`.

## Naming and shape

Name tests `test_<what>_<condition>_<expected>` so a CI failure line names what
broke.

Fixtures over setup methods. `@pytest.mark.parametrize` for variations of one
assertion. `tmp_path` for anything touching the filesystem — never a hardcoded
temp dir, never the repo tree.

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

Declaring markers silences `PytestUnknownMarkWarning`. CI runs `-m unit` on every
push, the full suite on merge.

`pytest-xdist` for parallelism, `pytest-cov` for coverage.

## Record HTTP, don't call it

`pytest-recording`/VCR: record once, replay after.

Configure filtering **before** the first recording — a cassette is a committed
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

Re-record deliberately. Read the diff before committing it.

## Never duplicate a test class name

Two `class TestFoo:` in one module is not an error — the second rebinds the
first, and every test in the first vanishes from the run. It looks like a pass.
Compare test functions against collected count:

```bash
diff <(grep -c "def test" tests/unit/test_x.py) <(pytest tests/unit/test_x.py --collect-only -q | tail -1)
```

Read the collected count after adding tests.

## Prove a negative with a failing stub

To assert something is not called, make the stub fail. The assertion sits where
the wrong behaviour would happen:

```python
monkeypatch.setattr(
    type(source), "fetch_content",
    lambda self, ids: pytest.fail("a lifecycle refresh must not fetch content"),
)
```

## Assert the public surface

```python
def test_the_package_exports_only_its_entry_points():
    assert sorted(mypkg.__all__) == ["Config", "Pipeline"]

def test_internals_are_not_reachable_from_the_package_root():
    assert not hasattr(mypkg, "SELECT_COLUMN")
    assert not hasattr(mypkg, "column_filter")
```

Turns an agreement not to export something into a failing test.

## Two cheap tests for any repo

**Import test** — import every module in the package. Catches a broken import or
circular dependency before deploy.

**Version compatibility test** — when a framework is pinned to a narrow range,
assert the installed version falls inside it, so the pin and the assumption fail
together.
