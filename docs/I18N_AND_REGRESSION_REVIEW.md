# Review since v1.2.14 (Aug 2026)

This document is a fresh audit of everything changed after the **v1.2.14** reviewability release, why regressions appeared, and what still needs fixing before **v1.3.0**.

## Baseline: what v1.2.14 was

**v1.2.14** was a **behaviour-neutral** pass:

- Short module aliases (`Access->`, `PLUGIN_NAME`, etc.)
- `REVIEW.md` file map
- ERM wording in `Health.pm` and Tools deny page
- `_staff_may_manage` helper in `Tool.pm`

No i18n code. No template INCLUDE changes. Toolbar used English constants directly. **View / Manage buttons and upload were working** on DEV before the translation work started.

## Chronology after 1.2.14

| Version | Intent | What changed |
|---------|--------|--------------|
| **1.2.15** | Plugin-local i18n | New `I18N.pm`, `po/de-DE.po`, `po/fr-FR.po`; translate toolbar, REST `label`, Tools templates via `spc_i18n.inc` / `spc_t` MACRO; `ui` hash on `view`; hard `use I18N` in main plugin class |
| **1.2.16** | Fix 1.2.15 crashes | Remove broken `INCLUDE 'templates/spc_i18n.inc'`; stash `l` hash from Perl; lazy `require I18N`; fix `glob File::Spec` parse bug in `_po_path`; eval-guard translation |
| **1.2.17** | Fix upload + buttons | Harden `install`; toolbar eval wrapper; availability returns `manage` / `manage_url`; `is_staff_account` on staff REST; `staff_has_erm` expanded; `www.` strip in domains; access-log `LIMIT` fix |

## Current symptoms (your DEV report)

1. **Plugin upload → HTTP 500** (Tools still work afterward)
2. **Tools list / add / access log → OK**
3. **View login info / Manage login info → still missing** on catalog detail
4. **Translations → still English** when OPAC/staff language is de-DE or fr-FR

These symptoms are **not one bug**. They are three separate failure paths that were coupled in the 1.2.15–1.2.17 batch.

---

## Issue A: Upload 500

### How Koha upload works (24.11)

1. `plugins-upload.pl` extracts the `.kpz` into `pluginsdir`
2. `Koha::Plugins->InstallPlugins()` loads each plugin class and calls `new()`
3. `Koha::Plugins::Base::new()` runs `upgrade()` when package version > `__INSTALLED_VERSION__`
4. On success, redirects to `plugins-home.pl`
5. Optional `plugins_restart` sends **HUP** to Plack parent

### What 1.2.15–1.2.17 changed

- `install()` runs `CREATE TABLE IF NOT EXISTS` (unchanged logic, but now wrapped in `eval`)
- `upgrade()` still calls `install()` on every version bump
- Unique key changed to `publisher_name(191), …` (only applies on **new** installs; existing tables are not altered)

### Likely causes (ranked)

1. **Plack restart during upload** — `plugins_restart` HUP can interrupt the upload response and surface as 500 even when files were extracted and `InstallPlugins` completed.
2. **`UpgradeDied` / `InstallDied`** — if `install()` returns false and tables are missing, Koha records a failed upgrade (less common when Tools already work).
3. **Redirect target failure** — `plugins-home.pl` loads all plugins; a broken class can error on the home page (you might perceive this as “upload failed”).
4. **Stale Plack routes** — upload succeeds but new `openapi.json` / `staticapi.json` not active until Plack restart (would not usually be HTTP 500 on upload itself).

### What 1.2.17 did *not* fix reliably

Upload 500 can persist when the failure is **outside** `install()` (restart timing, home page load, Apache/Plack error). Treat upload 500 as **needs log confirmation**, not “fixed by eval in install”.

### Required verification

```bash
sudo tail -100 /var/log/koha/library/plack-error.log
# or
sudo journalctl -u koha-plack-library -n 50 --no-pager
```

Look for: `InstallDied`, `UpgradeDied`, `SPC install error`, or errors immediately after upload timestamp.

### Recommended code fix

- `upgrade()` should **not** re-run full `install()` when credentials table already exists (version bump only updates `__INSTALLED_VERSION__`).
- Log install failures clearly; return success when tables exist even if `CREATE TABLE` would fail on edge schemas.

---

## Issue B: Missing View / Manage buttons

Buttons appear only when **both** of these are true for a given bib:

1. **Domain match** — at least one registrable domain from the bib’s `856$u` URLs matches an active login’s Domains field, and the viewer’s library scope allows access.
2. **UI injection** — either the **Perl toolbar hook** or **`spc-staff.js`** successfully adds controls.

### Two independent code paths

| Path | Mechanism | Depends on |
|------|-----------|------------|
| **Perl** | `intranet_catalog_biblio_enhancements_toolbar_button` in `cat-toolbar.inc` | `Matcher->matching_credentials_for_biblio`, staff session, plugin enabled |
| **JavaScript** | `intranet_js` → `spc-staff.js` → `GET …/availability?interface=staff` | Static routes, Plack REST, same matcher |

Tools list showing logins does **not** prove detail-page match — the list is all credentials you may manage; detail requires **this bib’s 856 domains**.

### Regressions introduced after 1.2.14

| Change | Risk |
|--------|------|
| **1.2.17 `is_staff_account` gate** on `availability` / `view` when `interface=staff` | If `koha.user` from REST stash fails this check, API always returns `show: 0` while Perl toolbar might still work — or both fail if matcher also returns nothing |
| **Silent JS catch** | Any API 400/500 hides buttons with no console error unless DevTools open |
| **Matcher unchanged** except `www.` normalization (should help, not break) |

### What did *not* cause missing buttons in 1.2.16+

- Broken `spc_i18n.inc` INCLUDE (fixed; Tools work)
- `glob File::Spec` in I18N (fixed; would break toolbar labels, not remove buttons entirely if English fallback works)
- Missing `intranet_js` in Koha 24.11 — `intranet-bottom.inc` uses `get_plugins_intranet_js | $raw` (correct)

### Required verification (do this before more code changes)

On **catalogue/detail.pl** for a bib you expect to match:

1. **Page source** — confirm both scripts load (no `?v=`):
   - `/api/v1/contrib/secure_publisher_credentials/static/js/spc-config.js`
   - `/api/v1/contrib/secure_publisher_credentials/static/js/spc-staff.js`

2. **Availability API** (logged in as staff, replace `BIB`):

   `/api/v1/contrib/secure_publisher_credentials/biblios/BIB/availability?interface=staff&debug=1`

   | `show` | Meaning |
   |--------|---------|
   | `1` | Matcher + permissions OK → bug is JS/DOM (toolbar target) |
   | `0` | Check `debug.record_domains` vs login Domains field, or scope, or `is_staff_account` blocking |

3. **Plack log** — `SPC availability match error` or `toolbar button error`

### Recommended code fixes

1. **Remove `is_staff_account` gate** on staff REST — `interface=staff` + valid session is enough; matcher already enforces scope.
2. **Stop swallowing API errors in JS** — log `console.warn` in catch (dev visibility).
3. **Optional**: superlibrarian-only debug line in availability when `show=0` (reason code).
4. Do **not** add more i18n logic until buttons work in English.

---

## Issue C: Translations not working

### Root cause (design)

Koha **24.11 does not install plugin `.po` files** into core locales ([Bug 37472](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=37472) not in 24.11). The `.po` files on disk do nothing unless the plugin applies them at runtime. **v1.2.15+** added `I18N.pm` for that.

### What must work for translations to appear

| Surface | How label is produced | Language source |
|---------|----------------------|-----------------|
| Staff toolbar | `I18N->translate` in Perl hook | Cookie `KohaOpacLanguage` or `C4::Languages::getlanguage()` in **intranet** context |
| OPAC / staff JS link | REST `availability.label` | Cookie on same-origin fetch; REST runs as **api** interface |
| Tools templates | `l.*` from `I18N->template_labels` | CGI intranet context |
| Modal | REST `view.ui` | Same as availability |

### Known weaknesses in current `I18N.pm`

1. **Cookie only checks `KohaOpacLanguage`** — correct for OPAC and usually staff (Koha uses same cookie name for staff UI in 24.11).
2. **`C4::Languages::getlanguage()` without CGI** in API context uses `Koha::Language->get_requested_language()`, **not** the staff UI cookie — cookie-first ordering is essential for REST labels.
3. **PO parser** is single-line `msgid`/`msgstr` regex — fragile if `.po` entries are reformatted.
4. **`I18N.pm` must be in the deployed `.kpz`** — verify with `unzip -l …kpz | grep I18N`.
5. **JS fallback** — `spc-config.js` still has English `VIEW_LABEL`; patron sees translation only if API returns translated `label`.
6. **No translation for plugin name in Koha Plugins home** — metadata `name` comes from `Constants.pm` English string (cosmetic).

### Required verification for i18n

1. After switching to de-DE, confirm cookie in browser: `KohaOpacLanguage=de-DE`
2. Hit availability JSON — `label` should be `Anmeldedaten anzeigen`, not `View login info`
3. If cookie is correct but `label` is English → `I18N.pm` not loaded or PO path wrong on server
4. If `label` is German but button text English → JS using `spc-config` fallback (API not used or `show=0`)

### Recommended code fixes (after buttons work in English)

1. Harden `I18N.pm`: English defaults in `template_labels`; never return empty `l` hash.
2. Parse PO with line-by-line state machine (not one big regex).
3. Add `language` to availability `debug` payload for superlibrarians.
4. Document that **hard refresh** is required after language switch.
5. Keep `Constants.pm` / `spc-config.js` English msgids in sync with `po/*.po` msgids.

---

## Assessment: were 1.2.15–1.2.17 the right approach?

**Partially.**

- **Right**: Runtime PO lookup for 24.11; translating REST `label` and modal `ui`; removing Koha core gettext dependency.
- **Wrong**: Shipping broken template INCLUDE; compile-time `use I18N`; complex patches (1.2.17) before confirming **availability `show`** on DEV; layering `is_staff_account` without evidence.

**Better strategy going forward:**

1. **Stabilize** — English buttons + upload (revert risky gates, verify API).
2. **i18n** — one surface at a time (REST label → toolbar → Tools → modal).
3. **v1.3.0** — only after manual test plan passes in English + one non-English locale.

---

## Recommended fix batch (v1.2.18)

| Priority | Fix |
|----------|-----|
| P0 | Remove `is_staff_account` checks from `Controller.pm` |
| P0 | `upgrade()` skip `install()` when credentials table exists |
| P0 | English defaults in `Tool::_i18n_stash` when I18N fails |
| P1 | `console.warn` in `spc-staff.js` / `spc-opac.js` on API failure |
| P1 | Add `language` to availability debug payload |
| P1 | Verify `I18N.pm` + `po/*.po` in built `.kpz` (`unzip -l`) |
| P2 | PO parser hardening |
| P2 | Upload troubleshooting note (Plack log, `plugins_restart`) |

---

## Model / task assignment (for future work)

| Task type | Best fit |
|-----------|----------|
| Koha lifecycle, OpenAPI, Plack, upload/install | Deep Perl review (Opus-class) with log evidence |
| Regression mapping vs transcript | Structured diff review (medium reasoning) |
| i18n / PO / cookie / REST label chain | Implementation + one targeted test script |
| JS DOM / toolbar injection | Browser DevTools + small JS changes |

Do **not** stack i18n and stability in one DEV upload without API JSON confirmation between steps.
