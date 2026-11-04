# Recovering work from a crashed or ended session

When a session died mid-task (OOM, timeout, terminal closed) and the user asks
"what did we do / where did we leave off", reconstruct from two sources: the
on-disk working tree and the session store. Neither alone is sufficient.

## 1. Find the session

```sh
hermes sessions list                 # title, last-active, id
```

Match by title or by the most recent entry that touched the repo in question.
Session ids look like `local-<hex>`.

## 2. Export it to readable markdown

```sh
hermes sessions export --session-id <id> --format md <output-dir>
```

The export lands in `<output-dir>/<id>-<title-slug>.md`, not at the path you
pass — the positional argument is a *directory*, and the filename is derived.
A `manifest.jsonl` is written alongside it. Read the markdown; tool calls and
results are preserved, so you can see exactly which edits landed and which
failed.

## 3. Cross-check against the working tree

The transcript says what the agent *attempted*; the filesystem says what
actually landed. They diverge after a crash.

```sh
git status --short
git stash list
git diff --stat
git diff -- <file>          # for each file the transcript claims to have edited
```

- Uncommitted edits in the tree that the transcript never mentions are usually
  pre-existing work from an earlier session — do not attribute them to the
  crashed one.
- A stash (e.g. "pre-sync local work") may hold a chunk of work that was
  stashed, not lost. Inspect with `git stash show -p stash@{N}` before
  assuming it is gone.
- `composer.lock` / lockfile platform fields and content-hashes lag behind
  `composer.json` edits; validate with `composer validate`.

## 4. Report, do not re-do blindly

Summarise: what landed (verified on disk), what is pending (edits attempted but
not applied, installs not completed), and what is unrelated (work from other
sessions sharing the tree). Offer the concrete next step; do not silently
re-run apt installs or long commands that the previous session could not
finish (e.g. missing sudo password).

## Pitfalls

- The export's `--output` flag does not exist; the output path is a positional
  argument and the format choices are `jsonl`, `md`, `qmd`, `html`, `trace`
  (not `markdown`).
- `hermes sessions list` shows only recent sessions; older ones may need
  `hermes sessions list --limit N` or filtering by `--title`.
- A session that "consumed too much RAM" usually did so in a side task
  (reverse engineering, large file reads). The primary task's edits often
  landed before the crash — check git before assuming everything is lost.
- Do not treat the transcript as proof that an install succeeded; verify the
  binary/version on PATH.
