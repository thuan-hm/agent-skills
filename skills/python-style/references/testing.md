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

## Never assert a duplicate class name

Two `class TestFoo:` in one module is not an error — the second silently rebinds
the first, and every test in the first vanishes from the run. It looks like a
pass. This happened once for 11 tests, caught only by comparing `grep -c "def
test"` against the collected count:

```bash
diff <(grep -c "def test" tests/unit/test_x.py) <(pytest tests/unit/test_x.py --collect-only -q | tail -1)
```

Read the collected count after adding tests. A suite that stays green while
shrinking is worse than a red one.

## Prove a negative with a failing stub

To assert something is *not* called, make the stub fail rather than counting
calls. The assertion lives at the place that would be wrong:

```python
monkeypatch.setattr(
    type(source), "fetch_content",
    lambda self, ids: pytest.fail("a lifecycle refresh must not fetch content"),
)
```

## Assert the public surface

Encapsulation decays silently — one convenient re-export at a time. Pin it:

```python
def test_the_package_exports_only_its_entry_points():
    assert sorted(mypkg.__all__) == ["Config", "Pipeline"]

def test_internals_are_not_reachable_from_the_package_root():
    assert not hasattr(mypkg, "SELECT_COLUMN")
    assert not hasattr(mypkg, "column_filter")
```

Cheap, and it turns "we agreed not to export that" into a failing test.

## Two cheap tests worth having anywhere

- **Import test** — import every module in the package. Catches a broken import or a circular dependency before deploy, and costs one file.
- **Version compatibility test** — when a framework is pinned to a narrow range, assert the installed version falls inside it. The pin and the assumption then fail together, loudly, instead of drifting apart.
