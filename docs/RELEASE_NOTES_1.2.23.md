# Secure Publisher Logins v1.2.23

**Date:** August 2026  
**Koha target:** 24.11 (tested on instance `library`)

## Summary

Stabilizes staff and OPAC login links after incomplete `plugin_methods` registration on Koha 24.11, documents upload and recovery in an operations runbook, and introduces plugin-local translations for Tools and REST labels. English behaviour is the release gate on DEV; full locale verification is planned for v1.3.0.

## Highlights

- **Hook self-repair** — On plugin load, missing `plugin_methods` rows for `intranet_js`, toolbar, OPAC hooks, and `tool` are re-inserted so `spc-config.js` / `spc-staff.js` appear on catalogue pages again.
- **Repair script** — `bin/spc_repair_plugin_methods.pl` registers this plugin’s hooks only (safe when full `misc/devel/install_plugins.pl` fails on duplicate `api_namespace`).
- **Operations runbook** — `docs/OPERATIONS.md` covers upload HTTP 500 with `plugins_restart`, post-upload smoke test, SQL/script recovery, and log locations.
- **Staff toolbar JS** — Toolbar injection scoped to `#maincontentcontainer` / `#bibliodetails`; `btn-group` layout; retry and console warnings on failure.
- **Plugin-local i18n** — `I18N.pm` and `po/de-DE.po` / `po/fr-FR.po` for Tools templates and REST `label` fields (Koha 24.11 does not merge plugin PO into core locales).

## Fixes

- Missing **View login info** / **Manage login info** when Tools still worked (`run.pl` bypasses `plugin_methods`).
- `upgrade()` no longer re-runs full `install()` when the credentials table already exists.
- Removes stale `templates/spc_i18n.inc` from older uploads when present.
- Removes spurious `use constant` aliases from the main plugin class (fewer bogus `plugin_methods` entries).
- Deprecated file cleanup no longer warns with an empty message when `bundle_path` is unset.
- OPAC fetch failures log `console.warn` instead of failing silently.

## New files

| Path | Purpose |
|------|---------|
| `docs/OPERATIONS.md` | Upload, upgrade, smoke test, recovery |
| `docs/I18N_AND_REGRESSION_REVIEW.md` | Audit of regressions since v1.2.14 |
| `Koha/.../I18N.pm` | Plugin PO catalog lookup |
| `Koha/.../bin/spc_repair_plugin_methods.pl` | Hook registration repair |

## Documentation

- `INSTALLATION.md`, `MANUAL_TEST_PLAN.md`, `NEXT.md`, `README.md` — point to OPERATIONS-first workflow.
- `NEXT.md` — Option A (operations) → English manual test → Option B (locales) → v1.3.0.

## Upgrade notes (Koha 24.11)

1. Build and upload the `.kpz`; **HTTP 500 on upload is often normal** when `plugins_restart` is enabled.
2. Confirm the new **version** on **Administration → Plugins** (primary success check).
3. Run the smoke test in `OPERATIONS.md`: page source must include `spc-config.js` and `spc-staff.js`.
4. If login links are missing, run `spc_repair_plugin_methods.pl` or the `INSERT IGNORE` SQL in `OPERATIONS.md`.
5. **Do not** run full `misc/devel/install_plugins.pl` on 24.11 if it fails on duplicate `api_namespace` — it can worsen hook registration.

```bash
sudo koha-plack --restart library   # if scripts still missing after repair
```

## Known limitations

- Translations require staff/OPAC language set to de-DE or fr-FR and hard refresh; verify per `MANUAL_TEST_PLAN.md` before calling v1.3.0 done.
- Upload may still return 500 while install succeeds; always check Plugins page version and smoke test.

## Full change scope (since v1.2.14 commit)

- Hook registration self-heal and repair tooling
- `upgrade()` / deprecated file cleanup hardening
- Staff/OPAC JS reliability and toolbar targeting
- `I18N.pm`, PO catalogs, translated Tools templates
- REST availability `label` translation; expanded staff permission checks
- Operations and regression review documentation
