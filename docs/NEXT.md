# Next

## Production cutover

DEV sign-off complete (English + installed locales). Ship **v1.3.0** via [OPERATIONS.md](OPERATIONS.md):

1. Build from tagged release: `npm run build` → `npm run verify:kpz` (must show **1.3.0**)
2. Upload on production; confirm version on Plugins home
3. Post-upload smoke test (`spc-config.js` / `spc-staff.js`)
4. Run production section of [MANUAL_TEST_PLAN.md](MANUAL_TEST_PLAN.md)
5. Enter credentials in Tools; remove legacy clear-text publisher logins elsewhere

Keep [OPERATIONS.md](OPERATIONS.md) (or the SQL recovery block) available for the first production upload.

## Maintenance

- **New UI string** — Update `de-DE.po` / `fr-FR.po`, `po/catalogs.json`, `npm run i18n:po`, `npm run i18n:verify`
- **New Koha locale** — Add to `po/catalogs.json`, regenerate PO, document in [I18N_LOCALES.md](I18N_LOCALES.md)
- **Weblate alignment** — `./scripts/list-weblate-languages.sh 66` (LF line endings; see I18N_LOCALES.md)

## Deferred / optional

- Further locales below Koha Weblate threshold
- Production monitoring beyond Koha action log / Plack error log
