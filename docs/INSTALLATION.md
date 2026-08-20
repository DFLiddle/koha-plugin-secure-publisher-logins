# Installation Guide (non-developers)

These steps assume Koha instance name **`library`** on Ubuntu/Debian-style packages.

## 1. Prerequisites

Complete every item in [PREREQUISITES.md](PREREQUISITES.md) before installing the plugin.

## 2. Obtain the `.kpz` file

**Option A — Download from GitHub (recommended)**

1. Open https://github.com/DFLiddle/koha-plugin-secure-publisher-logins/releases
2. Download the latest `koha-plugin-secure-publisher-logins.kpz` from the release assets

**Option B — Build from source** (requires Node.js on a workstation)

```bash
git clone https://github.com/DFLiddle/koha-plugin-secure-publisher-logins.git
cd koha-plugin-secure-publisher-logins
npm ci
npm run build
```

The file appears in `dist/koha-plugin-secure-publisher-logins.kpz`.

## 3. Upload the plugin

1. Staff interface → **Administration → Plugins**
2. Click **Upload plugin**
3. Select the `.kpz` file
4. Submit

The browser may show **HTTP 500** even when the install succeeded. Do not use the error banner as the only success signal.

**After upload:** follow [OPERATIONS.md](OPERATIONS.md) — confirm version on the Plugins list, restart Plack if needed, and run the post-upload smoke test (page source must include `spc-config.js` and `spc-staff.js`).

## 4. Enable the plugin

1. On the Plugins list, find **Secure Publisher Logins**
2. Ensure it is **Enabled**
3. If you see configuration warnings, resolve them (see [CONFIGURATION.md](CONFIGURATION.md))

## 5. Restart services

If Plack did not already restart during upload (`plugins_restart` in `koha-conf.xml`):

```bash
sudo koha-plack --restart library
```

## 6. Verify on development first

Run [MANUAL_TEST_PLAN.md](MANUAL_TEST_PLAN.md) on your dev instance before production.

## 7. Add logins

1. **Tools → Tool plugins → Secure Publisher Logins**
2. **Add login info**
3. Enter publisher name, domains, username, password, and **Accessible by** scope
4. Save

## 8. Test on a bibliographic record

1. Ensure the record has an `856$u` URL whose registrable domain matches a login
2. OPAC (logged-in patron): **View login info** in the actions menu
3. Staff **detail.pl**: **View login info** in the toolbar

## Troubleshooting

| Symptom | Check |
|---------|--------|
| No OPAC link | Patron logged in? Home library matches scope? `856$u` domain matches? Health checks pass? |
| Upload HTTP 500 | See [OPERATIONS.md](OPERATIONS.md) — confirm version on Plugins page after Plack restart |
| View login missing after upgrade | [OPERATIONS.md](OPERATIONS.md) smoke test and recovery section |
| Plugin upload fails (no version change) | `enable_plugins=1`, `plugins_restricted=0` |
| Decrypt errors after DB restore | Same `encryption_key` in dev and prod `koha-conf.xml` |
| Translations | Plugin ships PO catalogs in `po/` (see [I18N_LOCALES.md](I18N_LOCALES.md)). Enable languages in **OPACLanguages** / **StaffInterfaceLanguages**, switch UI language, hard-refresh. No `koha-translate` step. |

For upload, upgrade, `plugin_methods` recovery, and log interpretation, use **[OPERATIONS.md](OPERATIONS.md)**.
