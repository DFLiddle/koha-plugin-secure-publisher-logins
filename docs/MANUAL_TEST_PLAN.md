# Manual Test Plan

Run on **dev** (`dev.teamwork-global.net`) before production. Check each box.

## Installation

- [ ] `.kpz` uploads without error
- [ ] Plugin appears as **Secure Publisher Credentials** and is enabled
- [ ] Prerequisites page shows no red errors (Tools → Tool plugins → Secure Publisher Credentials)

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

- [ ] Bib with matching `856$u` shows **View login info**
- [ ] **Manage login info** visible for `erm` staff, hidden without `erm`
- [ ] Wrong-library staff member does not see buttons
- [ ] Click **View login info**: modal opens; staff note visible; username copy keeps modal open; password copy closes modal
- [ ] Valid `856$u`: new tab opens in background
- [ ] Malformed `856$u` (if test record available): plain text in modal, no new tab

## Matching — OPAC opac-detail.pl

- [ ] Logged-in patron (correct library): **View login info** in actions menu
- [ ] Modal matches staff (without staff note)
- [ ] Logged-out visitor: no link
- [ ] Blocked/expired patron: no link
- [ ] Wrong-library patron: no link

## Logging

- [ ] After OPAC view, log row uses **AnonymousPatron** borrowernumber
- [ ] After staff edit, log row uses staff borrowernumber
- [ ] Log modal shows entries; no username/password in log

## Permissions — All scope

- [ ] All staff can **view** All-scope credential on matching record
- [ ] Only superlibrarian can **edit** All-scope credential

## i18n

Currently **failing** — see [NEXT.md](NEXT.md). `.po` files exist; UI still shows English.

- [ ] Switch OPAC to **de-DE** or **fr-FR**; **View login info** string appears translated (after `.po` install)

## Plugin disable/re-enable

- [ ] Disable plugin: no OPAC/staff controls
- [ ] Re-enable: controls return; data intact

## Production cutover (after dev sign-off)

- [ ] Deploy `.kpz` to production
- [ ] Enter credentials manually
- [ ] Remove legacy clear-text from Pages / HTML customizations
