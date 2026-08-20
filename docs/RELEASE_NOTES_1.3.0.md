# Secure Publisher Logins v1.3.0

**Date:** August 2026  
**Koha target:** 24.11 LTS (instance `library` tested on DEV)

## Summary

First stable release with plugin-local translations, Koha 24.11 hook recovery, and an operations runbook. Staff and OPAC labels, Tools UI, and REST `label` fields follow the user’s Koha language when `po/*.po` exists for that locale.

## Highlights

- **45 locale catalogs** — `po/*.po` for site languages (`id-ID`, `th-TH`, `zh-Hans-CN`, `zh-Hant-TW`, `zh-CN`, `zh-TW`) plus Koha Weblate high-completion locales (see [I18N_LOCALES.md](I18N_LOCALES.md)).
- **Runtime i18n** — `I18N.pm` loads plugin PO files (Koha 24.11 does not install plugin PO into core; Bug 37472).
- **Staff + OPAC** — Translated toolbar/modal/Tools via Perl hooks, REST availability/view, and injected `window.SPC` labels.
- **Hook self-repair** — Missing `plugin_methods` rows (including `enable` / `disable`) re-inserted on load; `spc_repair_plugin_methods.pl` for safe recovery.
- **Operations runbook** — [OPERATIONS.md](OPERATIONS.md): upload 500, smoke test, recovery SQL, logs.
- **Build checks** — `npm run build` verifies version sync, kpz contents, and PO catalogs (`i18n:verify`).

## Fixes since v1.2.14

- Plugins page **Disable** works when `enable` / `disable` were missing from `plugin_methods`.
- REST availability/view return empty when plugin disabled (until Plack restart).
- Staff translations when `KohaOpacLanguage` cookie differs from `StaffInterfaceLanguages` / `OPACLanguages` sysprefs.
- Tools pages use `C4::Context->query` for language cookie (not bare `CGI->new`).
- Staff JS refreshes toolbar labels from API when Perl toolbar rendered English first.
- `upgrade()` skips full `install()` when credentials table exists.
- Upload/build: `verify-kpz.js` confirms `$VERSION` inside the `.kpz`.

## New tooling

| Script | Purpose |
|--------|---------|
| `npm run i18n:po` | Generate `.po` from `po/catalogs.json` |
| `npm run i18n:verify` | Match all PO msgids to `de-DE.po` |
| `npm run verify:kpz` | Confirm built kpz version |
| `scripts/list-weblate-languages.sh` | Koha Weblate locales above threshold |
| `bin/spc_repair_plugin_methods.pl` | Register hooks without full `install_plugins.pl` |

## Upgrade notes (Koha 24.11)

1. `npm run build` → upload `dist/koha-plugin-secure-publisher-logins.kpz`.
2. HTTP **500** on upload may be normal with `plugins_restart`; confirm **1.3.0** on Plugins home.
3. Smoke test: `spc-config.js` and `spc-staff.js` in staff detail page source.
4. Enable locales in **StaffInterfaceLanguages** / **OPACLanguages**; switch language; hard refresh.
5. If hooks missing: repair script or SQL in [OPERATIONS.md](OPERATIONS.md) — not full `install_plugins.pl`.

## Production

Follow [OPERATIONS.md](OPERATIONS.md) and [MANUAL_TEST_PLAN.md](MANUAL_TEST_PLAN.md) cutover section after DEV sign-off.
