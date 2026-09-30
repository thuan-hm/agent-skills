# agent-skills

My personal Claude Code skills — data, AI, backend, and whatever else earns one.

## Install

```bash
git clone git@github.com:thuan-hm/agent-skills.git ~/Projects/agent-skills
~/Projects/agent-skills/install.sh
```

The script symlinks every `skills/<name>` into `~/.claude/skills`, and clones
pinned third-party skills (listed in `VENDORED` at the top of the script) into
`~/.claude/vendor`, linking them the same way. Re-run it after `git pull` to
pick up new skills; bump a `sha` there to take upstream updates. Restart Claude
Code afterwards.

## Skills

| Skill | Domain | Use it to |
| --- | --- | --- |
| [python-style](skills/python-style/SKILL.md) | python | structure and review Python for data, AI, and backend work |

Skills stay flat in `skills/`, one directory each, regardless of domain — Claude Code
only finds `~/.claude/skills/<name>/SKILL.md` one level deep, so grouping
happens in this table, not in subfolders.

## Layout

```text
install.sh           # links skills/ and pinned third-party skills into ~/.claude/skills
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
