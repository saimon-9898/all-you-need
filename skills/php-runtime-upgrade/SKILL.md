---
name: php-runtime-upgrade
description: "Bump PHP version and verify. Use when upgrading PHP runtime."
category: software-development
version: 1.0.0
author: hermes-agent
license: MIT
metadata:
  hermes:
    tags: [php, laravel, docker, composer, version-bump]
    related_skills: [opencode, verification-loop]
---

# PHP Runtime Upgrade

## When to Use

Use when a Laravel or PHP project's declared PHP version must change, including composer constraints, lock platform, Docker base images, docs, and runtime verification.

## Procedure

1. Find every PHP-version surface before editing:
   - `backend/composer.json` (`require.php`)
   - `backend/composer.lock` (`platform.php` + `content-hash`)
   - `backend/Dockerfile` (`FROM php:X.Y...-fpm-alpine` and the header comment)
   - `docs/deployment.md`, `AGENTS.md`, CI workflows, `railway.json`
   - any `.php-version` / tool-version files
2. Make the source edits with the opencode CLI (user preference), not by hand:
   ```sh
   opencode run --standalone --auto -m moonmath/deepseek-v4.1-flash "Update declared PHP version to 8.5.12 in ..."
   ```
   Pick a working model from `opencode models`; the exact model id changes.
3. Refresh the lock file after `composer.json` changes. The running PHP may be older than the new floor, so bypass platform checks:
   ```sh
   docker run --rm -v "$PWD/backend:/app" -w /app composer:2 \
     composer update --lock --ignore-platform-reqs
   ```
   Then `composer validate`.
4. Pin the Docker base image to the exact patch when the tag exists; verify with `docker manifest inspect php:8.5.12-fpm-alpine` before editing.
5. Verify under the new runtime with Docker, not the host PHP:
   ```sh
   docker run --rm -v "$PWD/backend:/app" -w /app php:8.5.12-cli bash -c '
     apt-get update -qq && apt-get install -y -qq libgd-dev libjpeg-dev libzip-dev libicu-dev
     docker-php-ext-configure gd --with-jpeg
     docker-php-ext-install -j$(nproc) gd pcntl zip intl
     php artisan test
   '
   ```
   The official image ships pdo_sqlite but not gd-with-jpeg, pcntl, zip, or intl; install them or image/upload tests fail with "imagejpeg function is not defined".
6. Separate pre-existing failures from new ones: rerun the failing tests on the *old* runtime (or inspect the error) before blaming the version bump. Pathao-stub and throttle-timing failures are environment/timing, not PHP-version regressions.

## Pitfalls

- `composer.lock` keeps the old `platform.php` and a stale `content-hash` after you edit `composer.json`; `composer validate` warns until the lock is refreshed. Always run `composer update --lock`.
- After a crashed or interrupted session, re-verify on-disk state before declaring the bump complete: `git status`, `git diff` on the four edited files, `composer validate`, and `php --version` on PATH. A transcript claiming "done" is not proof — the working tree may be ahead of committed state and the lock may still be stale.
- Do not document a host PHP version that is not actually installed. If the system binary lags, keep `AGENTS.md`/dev notes accurate or annotate the target version; use Docker for verification.
- Installing system PHP requires sudo; if no password is available, skip the host install and verify in Docker instead of faking it.
- Extension availability differs between the host package set and the official Docker image; test the same extension set the app actually needs.
