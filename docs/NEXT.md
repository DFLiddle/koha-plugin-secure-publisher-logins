# Next

## 1. Operations runbook (Option A) — do this first

Follow **[OPERATIONS.md](OPERATIONS.md)** for every upload on DEV and production:

- Expect upload **500** with `plugins_restart`; confirm **version** on Plugins home
- Post-upload smoke test: `spc-config.js` / `spc-staff.js` in page source
- Recovery via `spc_repair_plugin_methods.pl` or SQL — **not** full `install_plugins.pl` on 24.11

Deploy **1.2.24+** so enable/disable repair and hook self-repair are on the server.

## 2. Stabilize English on DEV

```bash
cd ~/Projects/koha-plugin-secure-publisher-logins
npm run version:check && npm run build
```

Upload using [OPERATIONS.md](OPERATIONS.md), then run [MANUAL_TEST_PLAN.md](MANUAL_TEST_PLAN.md) (English sections).

## 3. Translations (Option B) — after A

See [ARCHITECTURE.md](ARCHITECTURE.md) (i18n row) and `I18N.pm` / `po/*.po`.

1. Switch staff/OPAC to **de-DE**; confirm cookie `KohaOpacLanguage=de-DE`; hard refresh
2. API: `/api/v1/contrib/secure_publisher_credentials/biblios/BIB/availability?interface=staff&debug=1` — `label` and `debug.language` should reflect German
3. Toolbar, modal, Tools labels
4. Repeat for **fr-FR**
5. Fix code/PO only where tests fail

## 4. Release v1.3.0

When English manual test plan passes and required locales pass:

- Bump version, tag, GitHub release `.kpz`
- Production cutover via [OPERATIONS.md](OPERATIONS.md)
