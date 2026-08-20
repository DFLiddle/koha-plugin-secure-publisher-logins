# Secure Publisher Logins v1.3.1

**Date:** August 2026  
**Koha target:** 24.11 LTS (DEV + KTD validated)

## Summary

Bugfix release after **v1.3.0**. Fixes Koha 24.11 `InstallPlugins` / plugin upload failing with `Duplicate entry … api_namespace`, and documents the root cause in [OPERATIONS.md](OPERATIONS.md). All v1.3.0 features (plugin-local i18n, hook recovery, operations runbook) are unchanged.

## Fix

**`API_NAMESPACE` vs `api_namespace` collision in `plugin_methods`**

Importing `API_NAMESPACE` from `Constants.pm` into the main plugin class (since v1.2.12) registered a public `API_NAMESPACE` method. Koha’s REST hook name is `api_namespace`. On MySQL with `utf8mb4_unicode_ci`, those two `plugin_method` values collide on the primary key:

1. `InstallPlugins` inserts `API_NAMESPACE`
2. Insert of `api_namespace` fails with duplicate key
3. Upload / `install_plugins.pl` aborts; self-heal and repair could skip `api_namespace` because the wrong row satisfied a case-insensitive lookup

**Code changes**

- Do not import `API_NAMESPACE` into `SecurePublisherCredentials.pm`; `api_namespace` returns `Constants::API_NAMESPACE`
- Self-heal and repair script remove a stray `API_NAMESPACE` row when `api_namespace` is missing
- Comment in `Constants.pm` warns against re-importing `API_NAMESPACE` into the main class

## New / updated tooling

| Script | Purpose |
|--------|---------|
| `bin/spc_diagnose_plugin_methods.pl` | Compare Class::Inspector vs `plugin_methods`; warn on `API_NAMESPACE` without `api_namespace` |
| `bin/spc_repair_plugin_methods.pl` | Also migrates `API_NAMESPACE` → `api_namespace`; loads plugin with `enable_plugins => 1` |

## Documentation

- [OPERATIONS.md](OPERATIONS.md) — Root cause for duplicate `api_namespace`; diagnose script usage; no fragile `perl -e` one-liners

## Upgrade notes (from v1.3.0 or earlier on Koha 24.11)

1. `npm run build` → `npm run verify:kpz` (must show **1.3.1**)
2. Upload `.kpz`; confirm **1.3.1** on Plugins home
3. Optional before upload if hooks were broken: run repair script or delete `API_NAMESPACE` from `plugin_methods` (see OPERATIONS.md)
4. Smoke test: `spc-config.js` / `spc-staff.js` in staff detail page source; spot-check one non-English locale if used

**Existing installs:** Uploading v1.3.1 is enough; opening Tools or running the repair script cleans up a leftover `API_NAMESPACE` row on first load.

## Validation

- DEV (`library`): upload, locales, hook registration
- KTD: upload and install on Koha 24.11

## Production

Ship **v1.3.1** (not v1.3.0) for production cutover per [NEXT.md](NEXT.md) and [MANUAL_TEST_PLAN.md](MANUAL_TEST_PLAN.md).
