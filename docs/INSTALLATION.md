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
4. Confirm installation succeeded (no error banner)

## 4. Enable the plugin

1. On the Plugins list, find **Secure Publisher Logins**
2. Ensure it is **Enabled**
3. If you see configuration warnings, resolve them (see [CONFIGURATION.md](CONFIGURATION.md))

## 5. Restart services (if prompted)

On the server:

```bash
sudo systemctl restart apache2
# or your site’s koha-plack / apache config
```

## 6. Verify on development first

Run [MANUAL_TEST_PLAN.md](MANUAL_TEST_PLAN.md) on `dev.teamwork-global.net` before production.

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
| Plugin upload fails | `enable_plugins=1`, `plugins_restricted=0` |
| Decrypt errors after DB restore | Same `encryption_key` in dev and prod `koha-conf.xml` |
| Staff cannot manage | `erm` permission; for **All** scope need superlibrarian |
