# Manual Test Plan

Run on **dev** (`dev.teamwork-global.net`) before production. Check each box.

## Installation

- [ ] `.kpz` uploaded; version on Plugins page matches build (HTTP 500 on upload may be normal — see [OPERATIONS.md](OPERATIONS.md))
- [ ] Post-upload smoke test: `spc-config.js` and `spc-staff.js` in staff detail page source
- [ ] Plugin appears as **Secure Publisher Logins** and is enabled
- [ ] Prerequisites page shows no red errors (Tools → Tool plugins → Secure Publisher Logins)

## Credential CRUD

- [ ] Superlibrarian can add **All libraries** credential
- [ ] `erm` staff (non-superlibrarian) **cannot** add **All libraries** credential
- [ ] `erm` staff can add credential for own library
- [ ] Staff without `erm` **cannot** open save/create forms
- [ ] Duplicate publisher + same scope shows error
- [ ] Invalid domain format (e.g. `not a domain!`) rejected on save
- [ ] Inactive credential saves and does **not** show on OPAC/staff detail

## Encryption

- [ ] In MySQL, `password_encrypted` column is not plain text

## Matching — staff detail.pl

- [ ] Bib with matching `856$u` shows **View login info** (`fa-solid fa-unlock` on toolbar and injected link)
- [ ] **Manage login info** visible for `erm` staff, hidden without `erm`
- [ ] Wrong-library staff member does not see buttons
- [ ] Click **View login info**: modal opens; staff note visible; username copy keeps modal open; password copy closes modal
- [ ] Valid `856$u`: new tab opens in background
- [ ] Malformed `856$u` (if test record available): plain text in modal, no new tab

## Matching — OPAC opac-detail.pl

OPAC action icons (v1.4.5+, Font Awesome 6): lock before label except unlock for view; `fa-regular fa-circle-question` after label for scope-denied and account-blocked. After upload, confirm OPAC header icons (cart, lists, login) still render (regression fixed in v1.4.14).

- [ ] Logged-in patron (correct library): **View login info** (`fa-unlock`) in actions menu
- [ ] Modal matches staff (without staff note)
- [ ] Logged-out visitor on domain-matching bib: **Log in to check access** (v1.4.1+)
- [ ] After login (in-scope): returns to record and credentials modal opens automatically
- [ ] Blocked/expired in-scope patron (v1.4.4+): **Login info not available** in actions menu
- [ ] Click opens modal with account message and mailto button for `help_email`
- [ ] After **Log in to check access** as blocked in-scope patron: return + blocked modal (not credentials)
- [ ] Wrong-library patron (v1.4.3+): **Library not subscribed** in actions menu
- [ ] Click **Library not subscribed**: modal with subscription message and **Suggest for purchase** link
- [ ] Log in via **Log in to check access** as out-of-scope patron: return to record + denial modal (no credentials modal)

## OPAC availability API (v1.4.0+ Phase 1)

See [OPAC_ACCESS_STATES.md](OPAC_ACCESS_STATES.md). OPAC UI may still match v1.3.1 until Phase 2; verify API with curl.

- [ ] Anonymous on domain-matching bib: `state=login_required`, `show=0`, label “Log in to check access”
- [ ] In-scope patron: `state=view_allowed`, `show=1`
- [ ] Wrong-library patron: `state=scope_denied`, `suggestion_url` set when `OPACBaseURL` configured
- [ ] Blocked patron (scope OK): `state=account_blocked`, `help_email` set
- [ ] Staff `availability?interface=staff` unchanged for in/out of scope

## Logging

- [ ] After OPAC view, log row uses **AnonymousPatron** borrowernumber
- [ ] After staff edit, log row uses staff borrowernumber
- [ ] Log modal shows entries; no username/password in log

## Permissions — All scope

- [ ] All staff can **view** All-scope credential on matching record
- [ ] Only superlibrarian can **edit** All-scope credential

## i18n

Plugin translations are applied at runtime from `po/*.po` (see [I18N_LOCALES.md](I18N_LOCALES.md)). After upload, confirm English first, then test site locales (`id-ID`, `th-TH`, `zh-Hans-CN`, `zh-Hant-TW`) and any other enabled Koha languages.

- [ ] Switch OPAC to **de-DE** or **fr-FR**; **View login info** appears translated
- [ ] Staff toolbar **View login info** / **Manage login info** match that language
- [ ] Tools list/form headings follow staff language

## Plugin disable/re-enable

- [ ] Disable plugin: no OPAC/staff controls
- [ ] Re-enable: controls return; data intact

## Production cutover (after dev sign-off)

Follow [OPERATIONS.md](OPERATIONS.md) on production.

- [ ] Deploy `.kpz` to production
- [ ] Enter credentials manually
- [ ] Remove legacy clear-text from Pages / HTML customizations
