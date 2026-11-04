# All You Need — Hermes Skills & Memories

This repository packages the complete set of Hermes Agent skills and persistent memories
from a working Hermes installation, so another device (or a fresh Hermes install) can
pick them up with one command.

## Contents

- `skills/` — every skill under `~/.hermes/skills` (category folders + `SKILL.md` files).
- `memories/` — `MEMORY.md` and `USER.md` (Hermes persistent memory).
- `install.sh` — copies everything into the correct Hermes locations.

## Install on another device

1. Install Hermes Agent first (see https://hermes-agent.nousresearch.com/docs).
2. Clone this repo and run the installer:

```bash
git clone https://github.com/saimon-9898/all-you-need.git
cd all-you-need
bash install.sh
```

The installer backs up any existing `~/.hermes/skills` and `~/.hermes/memories` to
`~/.hermes/backups/all-you-need-<timestamp>/` before copying.

## Manual install

```bash
cp -r skills/* ~/.hermes/skills/
cp memories/MEMORY.md ~/.hermes/memories/MEMORY.md
cp memories/USER.md ~/.hermes/memories/USER.md
```

## Notes

- Skills are loaded automatically by Hermes on next session start.
- Memories are injected into every session; keep them concise.
- If you already have skills/memories, review the backup before overwriting.
