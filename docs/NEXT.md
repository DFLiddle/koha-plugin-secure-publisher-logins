# Next

## v1.4.15 — released (August 2026)

Signed off on DEV: OPAC access states Phases 1–4, icons, header regression fix (v1.4.14), static-asset diagnostics and ops notes, OPAC access-state i18n prep (49 msgids, de/fr hand locales + generated catalogs).

**Tag:** `v1.4.15` — build `koha-plugin-secure-publisher-logins.kpz` via `npm run build`.

**Production cutover** from **v1.3.1** remains a separate decision after full v1.4.x acceptance on all subscribing libraries.

## Staff toolbar: “Library not subscribed” (planned)

**Goal:** On staff `catalogue/detail.pl`, when a credential matches the bib’s `856$u` domain but the logged-in staff patron’s library is **out of scope**, show a toolbar control (like OPAC) instead of hiding the plugin entirely.

| Piece | Detail |
|-------|--------|
| **Label** | `Library not subscribed` (same msgid as OPAC) |
| **Notice** | Same copy as OPAC scope-denied modal (`SCOPE_DENIED_MESSAGE`) |
| **Action button** | Staff purchase suggestion form: `/cgi-bin/koha/suggestion/suggestion.pl?op=add_form` (not the OPAC patron suggestion URL) |
| **API** | Extend `availability?interface=staff` to return `scope_denied` when domain match exists but scope fails (mirror OPAC payload fields where sensible) |
| **JS** | `spc-staff.js`: third toolbar button + info modal (reuse Bootstrap modal pattern from OPAC `spc-opac.js`) |
| **Out of scope** | `account_blocked` / `login_required` on staff (OPAC-only states); staff “View login info” when in scope unchanged |

Reference: [OPAC_ACCESS_STATES.md](OPAC_ACCESS_STATES.md) Phase 2–3 behaviour; staff toolbar currently only shows View/Manage when scope matches.

## Production cutover (v1.3.1 → v1.4.x)

When v1.4.x is tagged and accepted:

1. Build from tagged release: `npm run build` → `npm run verify:kpz`
2. Upload on production; confirm version on Plugins home
3. Post-upload smoke test (`spc-config.js` / static URLs / `koha-common restart` if needed)
4. Run production section of [MANUAL_TEST_PLAN.md](MANUAL_TEST_PLAN.md)
5. Enter credentials in Tools; remove legacy clear-text publisher logins elsewhere

Keep [OPERATIONS.md](OPERATIONS.md) (or the SQL recovery block) available for the first production upload.

## Maintenance

- **New UI string** — Update `de-DE.po` / `fr-FR.po`, `po/catalogs.json` (or patch script), `npm run i18n:po`, `npm run i18n:verify`; keep `js/spc-config.js` English fallbacks in sync with `Constants.pm`
- **New Koha locale** — Add to `po/catalogs.json`, regenerate PO, document in [I18N_LOCALES.md](I18N_LOCALES.md)
- **Weblate alignment** — `./scripts/list-weblate-languages.sh 66` (LF line endings; see I18N_LOCALES.md)
- **Broken hooks after upload** — `bin/spc_diagnose_plugin_methods.pl`, then `bin/spc_repair_plugin_methods.pl` (not full `install_plugins.pl`)

## Deferred / optional

- **OPAC modal polish (post–v1.4.15):** native Koha button theming on info-modal actions; account-blocked mailto button label (e.g. “Email your library”) instead of raw address
- **Suggest for purchase i18n:** extend Koha-aligned translations in `scripts/fix-suggest-for-purchase-i18n.mjs` as more locales are verified against Koha `opac-bootstrap` PO files
- Further locales below Koha Weblate threshold
- Production monitoring beyond Koha action log / Plack error log
- **Staff UX:** Koha-native warning screens when staff lack `erm` or login-editing rights (Tools deny pages / toolbar)
