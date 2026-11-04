#!/usr/bin/env bash
set -euo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
SKILLS_SRC="$(cd "$(dirname "$0")" && pwd)/skills"
MEMORIES_SRC="$(cd "$(dirname "$0")" && pwd)/memories"

if [ ! -d "$HERMES_HOME" ]; then
  echo "Hermes home not found at $HERMES_HOME. Install Hermes first." >&2
  exit 1
fi

BACKUP="$HERMES_HOME/backups/all-you-need-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"

if [ -d "$HERMES_HOME/skills" ]; then
  cp -a "$HERMES_HOME/skills" "$BACKUP/skills"
fi
if [ -d "$HERMES_HOME/memories" ]; then
  cp -a "$HERMES_HOME/memories" "$BACKUP/memories"
fi

mkdir -p "$HERMES_HOME/skills" "$HERMES_HOME/memories"
cp -r "$SKILLS_SRC"/* "$HERMES_HOME/skills"/
cp "$MEMORIES_SRC"/MEMORY.md "$HERMES_HOME/memories"/MEMORY.md
cp "$MEMORIES_SRC"/USER.md "$HERMES_HOME/memories"/USER.md

echo "Installed skills and memories into $HERMES_HOME"
echo "Backup saved to $BACKUP"
