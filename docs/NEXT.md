# Next

## Production cutover

DEV and KTD sign-off complete. Ship **v1.3.1** via [OPERATIONS.md](OPERATIONS.md):

1. Build from tagged release: `npm run build` → `npm run verify:kpz` (must show **1.3.1**)
2. Upload on production; confirm version on Plugins home
3. Post-upload smoke test (`spc-config.js` / `spc-staff.js`)
4. Run production section of [MANUAL_TEST_PLAN.md](MANUAL_TEST_PLAN.md)
5. Enter credentials in Tools; remove legacy clear-text publisher logins elsewhere

Keep [OPERATIONS.md](OPERATIONS.md) (or the SQL recovery block) available for the first production upload.

See [RELEASE_NOTES_1.3.1.md](RELEASE_NOTES_1.3.1.md) for the install/upload fix vs v1.3.0.

## Maintenance

- **New UI string** — Update `de-DE.po` / `fr-FR.po`, `po/catalogs.json`, `npm run i18n:po`, `npm run i18n:verify`
- **New Koha locale** — Add to `po/catalogs.json`, regenerate PO, document in [I18N_LOCALES.md](I18N_LOCALES.md)
- **Weblate alignment** — `./scripts/list-weblate-languages.sh 66` (LF line endings; see I18N_LOCALES.md)
- **Broken hooks after upload** — `bin/spc_diagnose_plugin_methods.pl`, then `bin/spc_repair_plugin_methods.pl` (not full `install_plugins.pl`)

## Deferred / optional

- Further locales below Koha Weblate threshold
- Production monitoring beyond Koha action log / Plack error log
