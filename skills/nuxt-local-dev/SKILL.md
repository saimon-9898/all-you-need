---
name: nuxt-local-dev
description: "Run a Nuxt 4 storefront against a Laravel/PHP API locally."
category: software-development
version: 1.0.0
author: hermes-agent
license: MIT
metadata:
  hermes:
    tags: [nuxt, vue, laravel, local-dev, monorepo, proxy]
    related_skills: [php-runtime-upgrade, verification-loop]
---

# Nuxt Local Dev Stack

## When to Use

Use when the user asks to run, start, restart, or localhost a Nuxt frontend that talks to a backend API on the same origin (cookie session). Applies to Nuxt 4 monorepos with a Laravel/PHP (or any) API.

## The trap (read first)

`nuxt dev` does NOT honor `routeRules` proxy entries — Nitro ignores proxy route rules in dev mode. So `/api/**` and `/storage/**` return 404 and the cookie-authenticated session has no same-origin path, even though the same config works in a production build. A dev run that "looks fine" is actually serving the mock surface. **Always run the production build locally.**

A second, related trap: `NUXT_PUBLIC_DATA_SOURCE` and `NUXT_API_PROXY` are read from `process.env` at config-load time, so they are baked into `.output` at build time. Building without `NUXT_PUBLIC_DATA_SOURCE=http` serves the mock admin surface (empty lists that look identical to a schema bug). Build with the variable set.

## Procedure

1. Backend first (from `backend/`):
   ```sh
   setsid nohup env PHP_INI_SCAN_DIR="/etc/php/8.4/cli/conf.d:$HOME/.php-sqlite" \
     php artisan serve --host=127.0.0.1 --port=8000 >> /tmp/.../backend.log 2>&1 < /dev/null &
   ```
   - Use `setsid` so the shell does not reap the process tree when the command returns.
   - The DB must be migrated and seeded; an empty DB returns 200 with zero items and looks like a working (but empty) app. Run `php artisan migrate` and `php artisan db:seed` if products are missing.
   - Verify: `curl -s http://127.0.0.1:8000/api/v1/catalog/products` should return items, not an empty array.
2. Build the frontend (from repo root) with the data source pinned:
   ```sh
   NUXT_PUBLIC_DATA_SOURCE=http npm run build
   ```
   (`npm run build` already wraps `nuxt build` with the pretend-cpus shim; do not bypass it.)
3. Run the frontend production server:
   ```sh
   setsid nohup env NUXT_PUBLIC_DATA_SOURCE=http NUXT_API_PROXY=http://127.0.0.1:8000 \
     node .output/server/index.mjs >> /tmp/.../frontend.log 2>&1 < /dev/null &
   ```
   Default port is 3000 (Nitro reads `NITRO_PORT || PORT`).
4. Verify end to end:
   - `curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3000/` → 200
   - Open a product page and an admin page; confirm data renders (not "could not be loaded").
   - Admin login: POST `/api/v1/admin/login` with the seeded staff credentials.

## Port forwarding / exposing the local stack

When the user wants a shareable URL for the local stack (demo, review, remote QA), tunnel the **frontend** port only — Nitro proxies `/api` and `/storage` to the backend server-side, so the same-origin cookie/CSRF flow keeps working through the tunnel.

```sh
setsid nohup /home/atbd/.local/bin/cloudflared tunnel --url http://127.0.0.1:3000 \
  >> /tmp/scratchpad/cf.log 2>&1 < /dev/null &
sleep 8
grep -o "https://[a-z0-9-]*\.trycloudflare\.com" /tmp/scratchpad/cf.log | head -1
```

- The URL is ephemeral and changes on every restart; verify liveness with `curl`, not the process name.
- Only the frontend (3000) is exposed; the backend stays on 127.0.0.1. Exposing 8000 directly would bypass the proxy and break cookie auth.
- The tunnel inherits whatever the backend is configured for — if `APP_DEBUG=true` / `SESSION_SECURE_COOKIE=false`, the exposed URL leaks debug info and unencrypted cookies. Treat any tunnelled URL as a dev preview, never production, and never share it as a release.
- `pkill -f` matches its own shell and can kill the tool session; stop tunnels by explicit PID and verify with `curl`.

## Ports and credentials (Ciel Shoe E-commerce)

- Backend: 127.0.0.1:8000; Frontend: 127.0.0.1:3000
- DB: MySQL `rbac_test` on 127.0.0.1:3306, user `ciel` / `ciel_local_pw` (table prefix `sa_`)
- Staff login: `shoetroop@mail.com` / `shoetroop@#12` (throttled 5/min per IP+email). Note: the password contains `#`, so in `.env` it MUST be quoted (`ADMIN_PASSWORD="shoetroop@#12"`) — dotenv treats an unquoted `#` as the start of a comment and truncates the value.
- PHP needs `PHP_INI_SCAN_DIR="/etc/php/8.4/cli/conf.d:$HOME/.php-sqlite"` for tests only; serving uses the default PHP binary.

## Admin catalogue surfaces (Nuxt)

- The list endpoint returns the full `Product` (with `images: ProductImage[]`), so thumbnails need no extra fetch: `product.images.find(i => i.isPrimary)?.url ?? product.images[0]?.url`.
- Delete flow: gate the button on `admin.can('catalogue:write')`; confirm with `ConfirmDialog` (`~/components/ui/ConfirmDialog.vue`) using a `pendingConfirmation` ref holding `{ title, message, confirmLabel, run }`; `run()` calls `repositories.catalogue.deleteProduct(id)` then `refresh()` from `useAdminAsyncData`; catch `RepositoryError` and surface it as `deleteError` — a 409 means the product is on an unfilled order and cannot be removed. Mutating the list by hand desyncs pagination; always `refresh()`.
- `storeImage` (URL-based) and `uploadImage` (file) are the two image paths. The backend validates `url` as an `http(s)` URL or a single-leading-slash path; `AssetUrlSchema` on the client must reject protocol-relative (`//host`) values — a plain `startsWith('/')` lets `//evil.com/x` through, which is an origin in disguise. Keep the two in sync.

## Pitfalls

- Do not run `nuxt dev` and expect `/api` to work — it will 404. Use the production build.
- A rebuild is required after any frontend code change; `.output` is not hot-reloaded.
- The mock surface (`NUXT_PUBLIC_DATA_SOURCE` unset) looks identical to a real, empty, or broken app. Always build with `NUXT_PUBLIC_DATA_SOURCE=http` and check that lists are populated.
- `NUXT_API_PROXY` must be a per-request value read in `server/middleware/api-proxy.ts`, never a `routeRules` proxy — a route rule is evaluated at `nuxt build` and inside a container that is build time.
- Kill/restart by explicit PID; `pkill -f` matches its own shell and can kill the tool session. Verify liveness with `curl`, not process names.
- When a Laravel resource is shared across two models whose foreign-key columns differ (e.g. `OrderItemResource` used for both `OrderDraftItem` and `Order`), coalesce the columns (`$this->resource->order_id ?? $this->resource->order_draft_id`) — otherwise one side emits `null` and the client Zod schema (`z.string()`) rejects the whole 200 response as `ValidationError`. The same applies to any field whose column name differs between the two models.
- When the frontend throws `ValidationError` against a 200, compare the client Zod schema against what the Laravel Resource actually emits (field names and nullability), not against a hand-written fixture. In particular, Zod's `.optional()` does **not** accept `null` — a field the backend serialises as `null` (e.g. `description`, `imageUrl`) must be `.nullable()` (or `.nullish()`), or every row fails validation. The error surfaces as a `RepositoryError`/`ContractViolationError` even though the HTTP status is 200.
- Backend feature tests need `PHP_INI_SCAN_DIR="/etc/php/8.4/cli/conf.d:$HOME/.php-sqlite"` to load the sqlite driver; without it every test errors with "could not find driver".
- A test that fails with a domain error mismatch (e.g. expected `COURIER_NOT_CONFIGURED`/`delivered`, got `INTERNAL_ERROR`/`sent`) is usually environmental, not a regression: the Pathao stub server on port 8899 isn't running, or the sqlite driver isn't loaded. Probe the stub (`curl http://127.0.0.1:8899/...`) and re-run the single test after starting it before debugging application code.
- Pathao `PATHAO_BASE_URL` must be the host only (e.g. `https://courier-api-sandbox.pathao.com` or `http://127.0.0.1:8899`); it must NOT include `/aladdin/api/v1`, because `PATHAO_TOKEN_PATH`/`PATHAO_ORDER_PATH` already carry the full path. Including it doubles the path (`…/aladdin/api/v1/aladdin/api/v1/issue-token`) and every call 404s. The same applies to any base URL + path pair: keep the base a host/origin and the path a full route.
- After `pnpm build`, a previously running Nitro process can keep serving the old `.output` and fail with `Cannot find module '.../chunks/build/pages-*.mjs'`. Kill it by explicit PID, confirm it is gone, then start a fresh process and verify with `curl` before reporting a URL. `pkill -f` is unsafe (matches its own shell); use the recorded PID.
- Laravel's `Storage::fake` persists its disk root under `storage/framework/testing/disks` between runs and can become root-owned; a permission-denied scan there blocks tests and tooling. Rename the directory out of the way (`mv disks disks.bak`) — the parent is writable even when the child isn't — instead of trying to delete it.
- When a service is intentionally idempotent (e.g. `createCategory` reuses by name), tests asserting a 422 conflict are stale — update the assertion to the reused result instead of weakening the service.
- `AssetUrlSchema`: reject protocol-relative (`//`) values; a leading-slash check alone lets `//host/path` through, which is an origin in disguise. Keep the client schema and the backend `url` validation rule in sync.
- Static assets: editing `public/` is not enough — Nitro caches file metadata at startup and serves a stale copy. Copy the new file into `.output/public/` AND restart the Nitro process; query strings do not bust it.
- `.env` values containing `#` (or other dotenv-special chars) must be quoted, or the value is silently truncated at the `#`.
- When moving a control between components, preserve its `data-testid` and `aria-*` attributes so existing tests keep passing; thread the new props and emits in both directions (page passes data down, component emits selection up). Rename loop variables that shadow a prop name (e.g. `v-for="variant"` over a `variant` prop) to avoid the `vue/no-template-shadow` lint warning. When moving a submit button out of its form, keep it functional — make it `type="button"` with an explicit `@click` (or use the `form` attribute) — and, when the destination section only renders for saved records, keep a fallback submit button in the form for the new-record case so creation stays possible.
- When adding a field to a nested backend resource (e.g. a product's primary image on an inventory variant), update every layer in the same change: the Laravel Resource (compute from the eager-loaded relation), the service's `with()` eager load, the frontend Zod schema (nested object + nullability), and the mock repository. A field present in the resource but absent from the schema (or vice versa) fails validation on every row.
- A tripwire test that counts exact call shapes (e.g. `preg_match_all` over `with('product:'.self::PRODUCT_SUMMARY_COLUMNS)`) must be updated when a legitimate change alters the call shape (such as wrapping it in an array to add a relation). Update the regex to match the new form and keep the count; do not weaken the assertion to make it pass.
- `useAdminAsyncData` caches by a hardcoded key; two mounts in one spec share an entry and `clearNuxtData` does not evict it. Page specs must mock the composable per case and call `admin.setSession()` first, because `can()` answers no until the session verdict arrives and write controls stay invisible without it.
- A new admin page that reaches for `useAsyncData` directly reintroduces the SSR failure; use `useAdminAsyncData` (server: false) for all `/admin/**` pages.
- Categories are a flat list (no paging) returned by `repositories.catalogue.listCategories()`; `createCategory` is idempotent by name (reuses the existing row), and `deleteCategory` returns 204 and conflicts (409) when products still reference the category.
- When you add a method to a shared repository interface, update the mock implementation in the same change — `tsc` fails the build otherwise.
- When verifying a rendered page with Playwright, use the `@playwright/test` package from the repo's `node_modules` (not `playwright`), run scripts with `NODE_PATH=<repo>/node_modules`, and capture `page.on('console')` errors plus a full-page screenshot. A 200 from `curl` only proves Nitro served HTML; it does not prove the client hydrated or that data loaded.
- TS: `Record<string, string>` cannot hold `undefined`; build a separate errors object instead of assigning `undefined` into it.
- Long-running processes (artisan serve, Nitro, cloudflared) started in a foreground terminal call hit the tool timeout and are killed; launch them as background processes and poll liveness with `curl` before reporting a URL.
- Stock is never set directly: a variant starts at 0 and every change — including initial stock on creation — must go through the inventory ledger as a signed movement (`repositories.inventory.adjust(variantId, { delta, reason, note })`). A form that wants to capture stock on creation should record a `received` movement after the record is created, then re-read the variant so the displayed balance reflects it. The `received` reason is inbound and needs no note; other reasons may be outbound or note-required, so validate against the reason's polarity before calling. Never add a `stock` field to `ProductSaveInput`/`VariantSaveInput` or to the backend create/update payloads — the schema and service deliberately omit it.
- If `pnpm` is unavailable, `npm run build` works against the committed `node_modules` and package scripts; do not install pnpm just to build.
- Controlled inputs bound through a computed setter (e.g. `v-model="addressModel"` where the setter writes `checkout.shippingAddress = value`): replacing the object reference makes Vue re-render the form and re-assign every input's `:value`, which resets the caret to the end of the field on each keystroke (reads as "the page reloads on every word"). Mutate in place instead (`Object.assign(checkout.shippingAddress, value)`) so the reference stays stable and the DOM remains the source of truth while typing. Watchers that read nested properties (e.g. a debounced quote keyed on `shippingAddress.city`) still fire because the inner properties changed. Also keep the inputs enabled during background validation/quote fetches — toggling `disabled` during a debounced quote greys the field and can drop focus, which reads as the page reloading; only lock the form during the actual submit.
- Admin forms that capture money: accept **major units** (taka) in the input and convert to minor units on save (`Math.round(Number(taka) * 100)`), and seed the input by dividing the stored minor amount by 100 — the same convention the product editor uses (`priceTaka = (amount / 100).toString()`). A field that takes raw minor units (labeled "Cost (minor units)") confuses operators: typing `150` stores 150 paisa and displays as `1.50 tk`. Keep the API contract in minor units; only the input semantics change. Apply to every money field in an admin form, including shipping cost and free-shipping thresholds, so the UI is consistent.
- Admin customers directory: lists registered accounts only (email+password+verification). Guest checkouts do NOT create a customer — `OrderService::confirmFromDraft` sets `customer_id` from the session (null for guests), and a `Customer` requires the registration/verification flow. The order's contact + shipping address live on the order (see `/admin/orders`). An empty customers list after guest-only orders is expected, not a bug. Do not try to "fix" it by auto-creating customers from orders.