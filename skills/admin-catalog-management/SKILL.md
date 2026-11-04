---
name: admin-catalog-management
description: "Use when editing products, variants, sizes, or stock."
category: software-development
version: 1.0.0
author: hermes-agent
license: MIT
metadata:
  hermes:
    tags: [laravel, nuxt, admin, catalog, products, variants, stock]
    related_skills: [admin-content-management, nuxt-local-dev, verification-loop]
---

# Admin Catalog Management

## When to Use

Use when adding or editing products, variants, sizes, prices, colours, or stock thresholds through the admin panel.

## Pattern

A product owns many variants. A variant is identified by size + colour, not by SKU alone. Stock never changes by editing a variant; it moves only through the inventory ledger.

## Backend Steps

1. Validate variant identity (size + colour) as unique per product.
2. Store `low_stock_threshold` as a raw integer count. Never convert it with money-minor helpers.
3. Create variants with zero stock; record any initial stock as a `received` adjustment through the inventory service.
4. Apply optional fields only when the request actually sends them, so omitted values are preserved.
5. Run backend feature tests for catalog and inventory flows.

## Frontend Steps

1. Use `useAdminAsyncData` with `server: false` for admin pages; set the admin session before permission checks.
2. Keep client Zod schemas in sync with backend field names and nullability.
3. Update all three repository layers together: interface, HTTP, and mock.
4. For size pills, allow long labels: auto width with a minimum, wrapping text, and padding. Fixed widths clip values such as `8(12cm | 06-12M)`.
5. To add several sizes at once, split the size input on commas/newlines and create one variant per size. Generate a per-size SKU when more than one size is entered.
6. Apply the same currency-minor conversion only to money fields (`unit_price_minor`, `compare_at_minor`); counts stay raw integers.
7. Typecheck, lint, build with `NUXT_PUBLIC_DATA_SOURCE=http`, then restart Nitro after killing stale processes.

## Verification

- Backend tests for catalog and inventory.
- Frontend typecheck, lint, unit tests.
- Production build.
- Browser verification of the product edit page, including saving a variant with a long size label and a low-stock threshold such as 5.

## Pitfalls

- `low_stock_threshold` is a count, not money: do not pass it through `toMinor()` or it is multiplied by 100.
- Product variant identity is size + colour; duplicate combinations must be rejected before save.
- Initial stock must be recorded through the inventory ledger, not written directly to the variant column.
- Size labels can be long; fixed-width pills clip them. Use auto width with wrapping.
- Admin pages that use `useAsyncData` reintroduce SSR failures; use `useAdminAsyncData`.
- Shared repository interfaces require matching mock implementations or `tsc` fails.
- After rebuilding, kill stale `node .output/server/index.mjs` processes before starting the new bundle.
- Never expose secrets or credentials in admin UI, logs, or skill files.
- For this user, perform coding changes via the opencode CLI.
