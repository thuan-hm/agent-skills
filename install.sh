#!/usr/bin/env bash
# Link this repo's skills, plus pinned third-party skills, into ~/.claude/skills.
# Safe to re-run: refreshes links, fetches pinned commits, never overwrites real folders.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
VENDOR_DIR="${CLAUDE_VENDOR_DIR:-$HOME/.claude/vendor}"

# name|git url|pinned sha — bump the sha to take updates
VENDORED=(
    "mattpocock-skills|https://github.com/mattpocock/skills.git|c55ee46073ed923f86ce59a5eb3b6d895095d1b7"
)

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

# Drop links left behind by skills that were renamed or removed.
for dest in "$SKILLS_DIR"/*; do
    if [[ -L "$dest" && ! -e "$dest" ]]; then
        case "$(readlink "$dest")" in
        "$REPO_DIR"/* | "$VENDOR_DIR"/*) rm "$dest" && echo "prune  $(basename "$dest")" ;;
        esac
    fi
done

for skill in "$REPO_DIR"/skills/*/; do
    link_skill "${skill%/}"
done

for entry in "${VENDORED[@]}"; do
    IFS='|' read -r name url sha <<<"$entry"
    dir="$VENDOR_DIR/$name"
    [[ -d "$dir/.git" ]] || git clone --quiet "$url" "$dir"
    git -C "$dir" fetch --quiet origin
    git -C "$dir" checkout --quiet "$sha"
    echo "pin    $name @ ${sha:0:7}"

    # Link only the skills the upstream plugin ships, not its drafts.
    python3 -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1]))["skills"]))' \
        "$dir/.claude-plugin/plugin.json" |
        while read -r rel; do link_skill "$dir/${rel#./}"; done
done

echo "done — restart Claude Code to pick up new skills"
