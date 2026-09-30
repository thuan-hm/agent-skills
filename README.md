# agent-skills

My personal Claude Code skills — data, AI, backend, and whatever else earns one.

## Install

```
/plugin marketplace add thuan-hm/agent-skills
```

```
/plugin install agent-skills@agent-skills
```

```
/plugin install mattpocock-skills@agent-skills
```

Send each command as a separate prompt. `mattpocock-skills` is third-party
(grilling, TDD, code review…), listed here pinned to a reviewed commit so one
marketplace sets up a new machine; bump the `sha` to take updates.

## Skills

| Skill | Domain | Use it to |
| --- | --- | --- |
| [python-style](skills/python-style/SKILL.md) | python | structure and review Python for data, AI, and backend work |

Skills stay flat in `skills/`, one directory each, regardless of domain — the
plugin loader looks for `skills/<name>/SKILL.md`, so grouping happens in this
table, not in subfolders.

## Layout

```text
.claude-plugin/
  marketplace.json   # what /plugin marketplace add reads; the plugin is "./"
  plugin.json        # name, version, description
skills/<name>/
  SKILL.md           # frontmatter: name + description only
  references/        # detail SKILL.md points at, loaded on demand
  LOCAL.md           # gitignored machine-specific overrides
```

## Local overrides

Committed skills stay generic, because this repo is public. Anything machine- or
company-specific — project IDs, dataset names, absolute paths — goes in a
`LOCAL.md` beside the `SKILL.md`, which is gitignored. A committed
`LOCAL.example.md` documents what belongs there.

## Adding a skill

The `description` is the only part always in context, so it decides whether the
skill ever loads — write it as a trigger ("use when..."), not a summary. Keep the
body to what the model doesn't already know, and push detail into `references/`.
