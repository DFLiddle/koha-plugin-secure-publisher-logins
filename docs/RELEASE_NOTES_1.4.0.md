# Secure Publisher Logins v1.4.0 (in progress)

**Date:** August 2026  
**Koha target:** 24.11 LTS

## Summary

OPAC access states ([OPAC_ACCESS_STATES.md](OPAC_ACCESS_STATES.md)): Phases 1–3 in v1.4.3; Phase 4 account-blocked UX in **v1.4.4**.

## v1.4.7 — OPAC trailing icon

- Scope-denied and account-blocked trailing icon: `fa-regular fa-circle-question` (lighter than solid info)
- Trailing icon weight fix in `spc.css` (see v1.4.9 for webfont loading on Koha 24.11)

## v1.4.13 — FA regular webfont URL

- `@font-face` uses `/opac-tmpl/lib/fontawesome/webfonts/fa-regular-400.woff2` (shared `lib/`, not `bootstrap/lib/`)
- Woff2 only (no `.ttf` fallback 404)

## v1.4.12 — Plugin compile fix (OPAC @font-face)

- **Fix:** `qq{...}` for inline `@font-face` ended at the CSS `}` before `</style>`, so the module failed to compile (“Unmatched ( in regex” at line 410). Use string concatenation instead.

## v1.4.11 — KPZ build fix

- Gulp build explicitly includes `SecurePublisherCredentials.pm` and the `SecurePublisherCredentials/` tree (fixes missing `Constants.pm` on upload)
- `verify:kpz` checks `Constants.pm`, `Controller.pm`, OpenAPI, and key JS/CSS inside the zip

## v1.4.10 — Plugin load fix

- **Fix:** v1.4.9 failed to compile (`\@font-face` in `qq{}` was parsed as array `@font` under `strict`)

## v1.4.9 — FA regular webfont fix

- Koha 24.11 has no `regular.min.css`; inline `@font-face` registers regular weight 400 using Koha’s `fa-regular-400` webfonts (URLs resolved like the Asset plugin, no version suffix on fonts)

## v1.4.8 — Regular icon weight fix

- Trailing `fa-circle-question` uses class `spc-icon-trailing` with explicit `font-weight: 400` (OPAC action links inherit bold weight from Koha/Bootstrap)

## v1.4.6 — Staff view icon

- Staff **View login info** uses `fa-solid fa-unlock` (toolbar hook + `spc-staff.js`), matching OPAC

## v1.4.5 — OPAC link icons

- Per-state Font Awesome 6 icons on OPAC actions menu links (see [MANUAL_TEST_PLAN.md](MANUAL_TEST_PLAN.md))

## v1.4.4 — Phase 4

- OPAC **Login info not available** when `state=account_blocked` (expired/debarred in-scope patron)
- Info modal with account message and `mailto:` link from `help_email`
- Post-login from **Log in to check access** opens blocked modal when appropriate
- `availability` sets `modal_message` for `account_blocked` (email from branch replyto → branch email → sysprefs)

## v1.4.3 — Phase 3

- OPAC **Library not subscribed** when `state=scope_denied`
- Info modal with subscription message and **Suggest for purchase** link (`suggestion_url`)
- After **Log in to check access**, out-of-scope patrons see denial modal on return (not silent page)
- `availability` adds `modal_message` and `suggestion_link_label`
- `window.SPC` bootstrap: `LIBRARY_NOT_SUBSCRIBED_LABEL`, `SCOPE_DENIED_MESSAGE`, `SUGGEST_FOR_PURCHASE_LABEL`
- **Fix:** v1.4.2 failed to load (`Error found whilst attempting to load plugin`) due to a Perl `strict` compile error in `_spc_label_bootstrap_script`. Do not use v1.4.2.

## v1.4.1 — Phase 2

- OPAC **Log in to check access** when `state=login_required`
- Koha login modal with `return` to same `opac-detail.pl` (fallback `opac-auth.pl`)
- After login, auto-open credentials modal when `view_allowed`
- `window.SPC.LOGIN_TO_CHECK_LABEL` from Perl i18n bootstrap

## v1.4.0 — Phase 1

- `Matcher::credentials_for_biblio_domains` — domain match without scope
- OPAC `availability` states: `hidden`, `login_required`, `view_allowed`, `scope_denied`, `account_blocked`
- `show` remains `1` only for `view_allowed`
- Staff `availability` unchanged; adds `state` field

## Not in this build

Phase 5: full locale PO catalogs and production cutover packaging.

## Upgrade notes

Build v1.4.13, upload `.kpz`, smoke test per [MANUAL_TEST_PLAN.md](MANUAL_TEST_PLAN.md).

Verify API with curl examples in [OPAC_ACCESS_STATES.md](OPAC_ACCESS_STATES.md).
