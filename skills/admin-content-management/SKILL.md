---
name: admin-content-management
description: "Use when making storefront sections admin-editable."
category: software-development
version: 1.0.0
author: hermes-agent
license: MIT
metadata:
  hermes:
    tags: [laravel, nuxt, admin, cms, content, media]
    related_skills: [nuxt-local-dev, verification-loop]
---

# Admin-Editable Storefront Content

## When to Use

Use when a storefront section (hero, marquee, reviews, FAQ, promo, media) must be added, edited, reordered, published, or removed through the backend admin panel instead of source code.

## Pattern

Use one generic content-section table with a JSON payload. Do not create a bespoke table per component unless the data has strong relational constraints (orders, inventory, users).

Core shape:

- `section_key` (unique string)
- `title` (nullable)
- `payload` (JSON)
- `position` (integer)
- `is_published` (boolean)
- timestamps

The payload holds all text, links, media URLs, lists, and component-specific fields.

## Backend Steps

1. Migration: create `content_sections` (or reuse an existing sections table) with the core shape above.
2. Model: cast `payload` to array/object; guard nullable fields explicitly.
3. Service:
   - list published sections ordered by `position`
   - get by key
   - upsert by key (update only fields present in the request; use `array_key_exists`, not `??`, so `null` clears a value instead of preserving the old one — especially for `media_url`/`media_type`/`payload`)

   - delete
   - upload media to the public disk and return a URL
4. Controller:
   - public read route for storefront consumption
   - admin CRUD routes plus media upload
5. Seeder: insert default section payloads so the storefront has content before admin edits.
6. Validate media mime types and sizes; store on a disk that persists beyond local container storage for production.

## Frontend Steps

1. Add a Zod schema for the section and save input. Match backend nullability exactly; use `.nullable()` or `.nullish()` for fields the backend serializes as `null` (Zod `.optional()` does not accept `null`).
2. Add the repository method to the public catalog interface, HTTP implementation, and mock implementation in the same change.
3. Add the admin repository interface and HTTP/mock implementations for CRUD and upload.
4. Build the admin page under `/admin/...` using `useAdminAsyncData` (`server: false`), not `useAsyncData`.
5. Set the admin session before permission checks; `can()` is false until the session verdict arrives.
6. Wire the storefront to fetch sections with static fallbacks so a missing or unpublished section does not blank the page.
7. When a section carries media, render it conditionally by `mediaType`: `<video>` for values starting with `video` (autoplay, muted, loop, playsinline) and `<img>` otherwise; size with `object-fit: cover`. Do not assume media is always an image.
8. Convert hardcoded storefront chrome (announcement bars, marquees, banners) into sections too, or they remain uneditable and drift from admin state.

## Verification

- Backend tests for service/controller behavior.
- Frontend typecheck, lint, and unit tests.
- Production build with `NUXT_PUBLIC_DATA_SOURCE=http`.
- Browser verification using the repo's `@playwright/test` package with `NODE_PATH=<repo>/node_modules`; capture console errors and full-page screenshots. A `curl` 200 only proves Nitro served HTML, not hydration or data loading.

## Pitfalls

- Laravel models with string primary keys must set `public $incrementing = false;` and `protected $keyType = 'string';`. Without them Laravel casts the id to `0`, which breaks Zod schemas expecting a string and makes admin lists appear empty.
- Match the admin list envelope exactly: backend returns `{ items, nextCursor?, totalCount? }`, so the frontend HTTP repository must parse an object and unwrap `.items`, not a bare array.
- Do not leave admin pages on `useAsyncData`; they reintroduce SSR failures.
- Keep client schemas and backend resources in sync on field names and nullability.
- Updating a shared repository interface requires updating the mock implementation or `tsc` fails.
- Build with `NUXT_PUBLIC_DATA_SOURCE=http`; the mock surface looks identical to a real empty app.
- Media stored only on local disk is insufficient for production; use persistent/object storage.
- Keep the multipart field name identical on both sides (`file`, `image`, etc.); a mismatch silently yields a 422 on upload.
- After rebuilding, kill any stale `node .output/server/index.mjs` process before starting the new one; otherwise the tunnel or browser keeps serving the old bundle even though the build succeeded.
- Video uploads are blocked by PHP's `upload_max_filesize`/`post_max_size` (often 2M/8M) before Laravel validation runs; restart `artisan serve` with `-d upload_max_filesize=64M -d post_max_size=72M` (or set them in php.ini) and keep the Laravel `max:` rule in KB aligned with that limit.
- The backend service must allowlist video mime types (`video/mp4`, `video/webm`) explicitly; do not rely on a generic file rule.
- When seeding sections with `updateOrCreate` keyed on `section_key`, preserve the existing primary key (`id ?? generate new`) so re-running the seeder does not orphan rows or churn ids; only generate a new id when the row is absent.
- Commit/push only after the admin page renders the new sections in a real browser; a `curl` 200 on the API is not enough.
- When a section's background image is rendered by a child element, give that child explicit dimensions or absolute positioning; a parent `aspect-ratio` does not propagate height to the child, leaving an empty box.
- Admin upload sets `mediaUrl` only; the operator must also set `mediaType` (e.g. `video` or `video/mp4`) or the storefront renders the media as an image.
- When an admin can clear a media URL, the backend upsert must distinguish "field omitted" from "field set to null"; `??` silently preserves the old value and makes removal impossible. Use `array_key_exists`.
- `toMinor()` (or any currency-minor conversion) is for money fields only. Never apply it to integer counts such as `low_stock_threshold`, stock, or position; store and send those as raw integers or they are multiplied by 100.
- Never expose secrets or credentials in admin UI, logs, or skill files.
- For this user, perform coding changes via the opencode CLI.
