---
name: harness-tool-installation
description: "Install tools, skills, MCP into Hermes and opencode."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [install, tools, skills, mcp, hermes, opencode, setup]
    category: autonomous-ai-agents
---

# Installing external tools into Hermes and opencode

Use when the user asks to install/use an external repo, CLI, MCP server, or skill pack and wants it available in BOTH Hermes and opencode. Apply the same checklist to each harness; a tool that only lands on one side is half-done.

## Procedure

1. Clone and inspect first.
   - `git clone <url> /tmp/scratchpad/<name>`
   - Read README and any install.sh/install.ps1. Identify: install method (npm global, pip/uv, copy skill folders, MCP server), supported harnesses, and node/python version floors.

2. Install the binary/tool.
   - npm-based: `npm install -g <pkg> --prefix ~/.local` (avoids sudo). Add `~/.local/bin` to PATH if missing.
   - Python-based: `uv tool install <pkg>` (or pipx). Confirm `which <bin>`.
   - If the installer has a version floor your runtime misses, try `--ignore-engines` (npm) — many tools still run. Do not block on a patch-level mismatch.

3. Install skills (copy or via the tool's own installer).
   - Copy skill folders: `cp -r <repo>/<skill-*> ~/.hermes/skills/` and `~/.config/opencode/skills/`.
   - If the tool ships its own installer with `--platform`, run it for BOTH `hermes` and `opencode` (many default to claude only — check).
   - graphify-style: `graphify install --platform hermes` and `--platform opencode` separately.

4. Register MCP servers on both sides.
   - Prefer the tool's setup command: `rea setup --client hermes --client opencode --yes` (or equivalent).
   - Otherwise edit config: Hermes `~/.hermes/config.yaml` (use `hermes config set`, never hand-edit YAML), opencode `~/.config/opencode/opencode.jsonc` / `opencode.json`.
   - Verify with the tool's doctor: `rea doctor` should show both clients `aligned`.

5. Verify auto-use.
   - Hermes: `skill_view(name)` loads the skill; `skills_list` shows it.
   - opencode: skill present in `~/.config/opencode/skills/`; MCP registered in config.
   - Restart both harnesses to pick up new skills/MCP (they load at startup).

6. Report to the user: what installed, where, and any restart needed.

## Pitfalls

- Many installers default to Claude only — always pass `--platform hermes` and `--platform opencode` explicitly, or copy skills manually.
- graphify's `graphify install` defaults to claude; run it twice with `--platform`.
- REA requires Node >=24.22.1; if your node is older, `npm install -g rea-agents --prefix ~/.local --ignore-engines` works and the binary still runs.
- ECC's opencode target needs a build step first: `npm run build:opencode` before `install.sh --target opencode`.
- opencode MCP config lives in `opencode.jsonc` (not `opencode.json`) in `~/.config/opencode/`.
- Hermes config must be edited via `hermes config set` — hand-editing YAML can corrupt it.
- Skills auto-trigger by relevance, not by being "enabled"; there is no global auto-load toggle. If a skill must always fire, reference it explicitly in the prompt or project instructions.
- Hooks are installed as files but only fire if the harness reads them; Hermes needs registration in config.yaml, opencode reads `hooks.json` automatically.
- apt on this machine is often broken (dependency solver timeouts); prefer uv/pip/npm over apt for tooling.
- PHP tests here need pdo_sqlite which is not installed; use MySQL or install the extension — do not treat missing pdo_sqlite as a code failure.

## User preferences

- User wants all coding work done via the opencode CLI (not other coding agents) — route coding tasks there.
- User wants installed tools available in BOTH Hermes and opencode; a single-side install is incomplete.
