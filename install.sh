#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
VENDOR_DIR="${CLAUDE_VENDOR_DIR:-$HOME/.claude/vendor}"
MANIFEST="$REPO_DIR/skills.yaml"

read_manifest() {
    python3 - "$MANIFEST" <<'PY'
import sys

sources = []
for raw in open(sys.argv[1]):
    item = raw.split("#", 1)[0].strip()
    if item in ("", "sources:", "skills:"):
        continue
    if item.startswith("- name:"):
        sources.append({"name": item.split(":", 1)[1].strip(), "skills": []})
    elif item.startswith("- "):
        sources[-1]["skills"].append(item[2:].strip())
    else:
        key, value = item.split(":", 1)
        sources[-1][key.strip()] = value.strip()
for src in sources:
    print("|".join([src["name"], src["repo"], src["sha"], " ".join(src["skills"])]))
PY
}

link_skill() {
    local src="$1" dest="$SKILLS_DIR/$(basename "$1")"
    if [[ -e "$dest" && ! -L "$dest" ]]; then
        echo "skip   $(basename "$src") — $dest is a real folder, not a link"
        return
    fi
    ln -sfn "$src" "$dest"
    echo "link   $(basename "$src")"
}

mkdir -p "$SKILLS_DIR" "$VENDOR_DIR"

for dest in "$SKILLS_DIR"/*; do
    if [[ -L "$dest" ]]; then
        case "$(readlink "$dest")" in
        "$REPO_DIR"/* | "$VENDOR_DIR"/*) rm "$dest" ;;
        esac
    fi
done

for skill in "$REPO_DIR"/skills/*/; do
    link_skill "${skill%/}"
done

read_manifest | while IFS='|' read -r name url sha paths; do
    dir="$VENDOR_DIR/$name"
    [[ -d "$dir/.git" ]] || git clone --quiet "$url" "$dir"
    git -C "$dir" fetch --quiet origin
    git -C "$dir" checkout --quiet "$sha"
    echo "pin    $name @ ${sha:0:7}"

    for rel in $paths; do
        link_skill "$dir/$rel"
    done
done

echo "done — restart Claude Code to pick up new skills"
