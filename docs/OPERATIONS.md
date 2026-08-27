# Operations runbook — upload, upgrade, and recovery

Use this document after every `.kpz` upload on Koha **24.11** (instance name **`library`** in examples below). It describes the workflow that works on DEV when `plugins_restart` is enabled in `koha-conf.xml`.

For first-time install, see [INSTALLATION.md](INSTALLATION.md). For acceptance testing, see [MANUAL_TEST_PLAN.md](MANUAL_TEST_PLAN.md).

## What “success” means after upload

| Signal | Success? |
|--------|----------|
| Browser shows **HTTP 500** on upload | **Often normal** — do not assume the install failed |
| Plack log shows `QUIT`, `HUP`, worker restart | **Often normal** when `plugins_restart` is on |
| Apache log shows `SIGWINCH` during `koha-common` restart | Normal during service restart |
| **Administration → Plugins** shows the new **version** | **Primary success check** |
| Tools page works | Good, but **not sufficient** (Tools use `run.pl`, not `plugin_methods` hooks) |
| Detail page source has `spc-config.js` / `spc-staff.js` | **Required** for staff/OPAC login links |

Tools can work while staff/OPAC pages have **no** login links if the `plugin_methods` table is incomplete. Always run the smoke test below.

## Standard upgrade workflow

Replace `library` with your Koha instance name.

### 1. Build the `.kpz` (workstation)

```bash
cd ~/Projects/koha-plugin-secure-publisher-logins
npm run build
```

`npm run build` runs `version:check`, builds the `.kpz`, then verifies `$VERSION` inside the zip matches `package.json`. You can re-check an existing build with `npm run verify:kpz`.

Before upload, confirm the file you will select in the browser:

```bash
npm run verify:kpz
# verify-kpz also checks Constants.pm and other required paths inside the zip
unzip -l dist/koha-plugin-secure-publisher-logins.kpz | grep Constants.pm
```

After upload, if Plugins shows **Error found whilst attempting to load plugin**, confirm the full tree exists on the server (not only the top-level `.pm`):

```bash
ls -la /var/lib/koha/library/plugins/Koha/Plugin/DFLiddle/SecurePublisherCredentials/Constants.pm
ls -la /var/lib/koha/library/plugins/Koha/Plugin/DFLiddle/SecurePublisherCredentials.pm
```

If `Constants.pm` is missing, rebuild with `npm run build`, re-upload `dist/koha-plugin-secure-publisher-logins.kpz`, restart Plack.

**Do not use bare `perl -c` on the main `.pm`** outside Koha’s environment. System `perl` lacks both `pluginsdir` and `/usr/share/koha/lib`, so you will see false errors (`Constants.pm`, `Koha::Database.pm`, etc.) even when the install is fine.

**Compile check (inside Koha shell):**

```bash
sudo koha-shell library -c "perl -c /var/lib/koha/library/plugins/Koha/Plugin/DFLiddle/SecurePublisherCredentials.pm"
```

Expect: `syntax OK`.

**Load / hook check:**

```bash
sudo koha-shell library -c "perl /var/lib/koha/library/plugins/Koha/Plugin/DFLiddle/SecurePublisherCredentials/bin/spc_diagnose_plugin_methods.pl"
```

Run with `perl …/spc_diagnose_plugin_methods.pl` (not execute the path directly) — the file is often not mode `+x`. The script should finish without “diagnose failed”.

**Filesystem check (optional):**

```bash
ls -la /var/lib/koha/library/plugins/Koha/Plugin/DFLiddle/SecurePublisherCredentials/Constants.pm
grep VERSION /var/lib/koha/library/plugins/Koha/Plugin/DFLiddle/SecurePublisherCredentials.pm
```

Use **`dist/koha-plugin-secure-publisher-logins.kpz`** from this build — not an older copy in Downloads and not a GitHub Release asset unless that release tag matches your build version.

### 2. Upload in staff

1. **Administration → Plugins → Upload plugin**
2. Select `dist/koha-plugin-secure-publisher-logins.kpz`
3. Submit

If the browser reports **500**, continue to step 3 — do not re-upload immediately.

### 3. Let Plack restart (or restart manually)

With `plugins_restart` enabled, Koha sends HUP/QUIT to Plack during `InstallPlugins`. Wait a few seconds.

If the staff UI is unresponsive or Plugins page errors:

```bash
sudo koha-plack --restart library
```

You do **not** need `sudo systemctl restart apache2` for a routine plugin upgrade unless your site policy requires it.

### 4. Confirm version on Plugins home

Open **Administration → Plugins** manually (do not rely on the upload redirect).

Find **Secure Publisher Logins** and confirm the **version** matches the build you uploaded (e.g. **1.2.24**).

If Plugins home still shows an old version after upload, see [Uploaded version does not change](#uploaded-version-does-not-change).

### 5. Post-upload smoke test (~5 minutes)

**A. Tools**

- **Tools → Tool plugins → Secure Publisher Logins** — list loads, no 500

**B. Staff scripts (critical)**

1. Open `catalogue/detail.pl?biblionumber=BIB` for a record you expect to match
2. View page source (Ctrl+U)
3. Confirm both URLs appear:

   - `/api/v1/contrib/secure_publisher_credentials/static/js/spc-config.js`
   - `/api/v1/contrib/secure_publisher_credentials/static/js/spc-staff.js`

**C. Staff buttons**

- On the same bib: **View login info** and **Manage login info** (if you have permission) appear and open the modal

**D. OPAC (optional but recommended)**

- Logged-in patron on matching `opac-detail.pl`: **View login info** in actions; modal works

If **B** fails (no `spc-` scripts in source), go to [Recovery: missing login links](#recovery-missing-login-links) — do not proceed to production.

### 6. Full acceptance (before tagging a release)

Run [MANUAL_TEST_PLAN.md](MANUAL_TEST_PLAN.md) on DEV.

## Recovery: missing login links

**Symptoms**

- Tools work
- Staff or OPAC detail pages have **no** View login links
- Page source has **no** `spc-config.js` / `spc-staff.js`
- Browser console is empty (scripts never loaded)

**Cause**

Koha registers UI hooks (`intranet_js`, `opac_js`, toolbar button, etc.) in the `plugin_methods` table during `InstallPlugins`. On Koha 24.11, a full `install_plugins.pl` run can fail with:

```text
Duplicate entry 'Koha::Plugin::DFLiddle::SecurePublisherCredentials-api_namespace' for key 'PRIMARY'
```

**Root cause (v1.3.1 fix):** Importing `API_NAMESPACE` from `Constants.pm` into the main plugin package (via `use Constants qw(... API_NAMESPACE ...)`) registers a public `API_NAMESPACE` method. Koha’s REST hook is `api_namespace`. On MySQL with `utf8mb4_unicode_ci`, those two `plugin_method` values collide on the primary key, so `InstallPlugins` inserts `API_NAMESPACE` then fails on `api_namespace`. Self-heal and the repair script can also skip adding `api_namespace` because the `API_NAMESPACE` row already satisfies a case-insensitive lookup.

Run `spc_diagnose_plugin_methods.pl`: if you see `API_NAMESPACE` in `plugin_methods` but not `api_namespace`, you have this state.

That failure can leave other hook rows missing while `tool` still works via `run.pl`. It can also omit `enable` / `disable`, so **Disable** on the Plugins page does nothing (Koha only invokes methods listed in `plugin_methods`).

**Do not use** `misc/devel/install_plugins.pl` on this Koha version for recovery. It processes **all** plugins and can repeat the failure.

### Option 1 — Repair script (preferred, v1.2.23+)

```bash
koha-shell library -c "/var/lib/koha/library/plugins/Koha/Plugin/DFLiddle/SecurePublisherCredentials/bin/spc_repair_plugin_methods.pl"
sudo koha-plack --restart library
```

The script registers only this plugin’s hooks and skips rows that already exist.

### Option 2 — SQL (`INSERT IGNORE`)

Use if the repair script is not deployed yet:

```bash
koha-mysql library -e "
INSERT IGNORE INTO plugin_methods (plugin_class, plugin_method) VALUES
('Koha::Plugin::DFLiddle::SecurePublisherCredentials', 'enable'),
('Koha::Plugin::DFLiddle::SecurePublisherCredentials', 'disable'),
('Koha::Plugin::DFLiddle::SecurePublisherCredentials', 'install'),
('Koha::Plugin::DFLiddle::SecurePublisherCredentials', 'uninstall'),
('Koha::Plugin::DFLiddle::SecurePublisherCredentials', 'upgrade'),
('Koha::Plugin::DFLiddle::SecurePublisherCredentials', 'intranet_js'),
('Koha::Plugin::DFLiddle::SecurePublisherCredentials', 'intranet_head'),
('Koha::Plugin::DFLiddle::SecurePublisherCredentials', 'intranet_catalog_biblio_enhancements_toolbar_button'),
('Koha::Plugin::DFLiddle::SecurePublisherCredentials', 'opac_js'),
('Koha::Plugin::DFLiddle::SecurePublisherCredentials', 'opac_head'),
('Koha::Plugin::DFLiddle::SecurePublisherCredentials', 'tool'),
('Koha::Plugin::DFLiddle::SecurePublisherCredentials', 'api_namespace'),
('Koha::Plugin::DFLiddle::SecurePublisherCredentials', 'api_routes'),
('Koha::Plugin::DFLiddle::SecurePublisherCredentials', 'static_routes'),
('Koha::Plugin::DFLiddle::SecurePublisherCredentials', 'cronjob_nightly');
"
sudo koha-plack --restart library
```

### Diagnose InstallPlugins / duplicate api_namespace (v1.3.0+)

Do **not** use `perl -e` one-liners through `koha-shell -c`: Koha runs the command under `/bin/sh`, which breaks on Perl’s `@`, `(`, and nested quotes (especially from PowerShell or SSH clients).

Use the plugin script (path only — no special quoting):

```bash
koha-shell library -c "/var/lib/koha/library/plugins/Koha/Plugin/DFLiddle/SecurePublisherCredentials/bin/spc_diagnose_plugin_methods.pl"
```

If that file is not on DEV yet (kpz older than the commit that added it), copy it from your checkout, then run the command above:

```bash
# From your workstation (adjust host and koha UNIX user if needed)
scp Koha/Plugin/DFLiddle/SecurePublisherCredentials/bin/spc_diagnose_plugin_methods.pl \
  dev.teamwork-global.net:/tmp/
ssh dev.teamwork-global.net 'sudo install -o koha-library -g koha-library -m 0755 \
  /tmp/spc_diagnose_plugin_methods.pl \
  /var/lib/koha/library/plugins/Koha/Plugin/DFLiddle/SecurePublisherCredentials/bin/'
```

Or open an interactive shell (paste multi-line Perl safely there):

```bash
koha-shell library
perl /var/lib/koha/library/plugins/Koha/Plugin/DFLiddle/SecurePublisherCredentials/bin/spc_diagnose_plugin_methods.pl
exit
```

The script prints Class::Inspector’s public method list (with duplicate counts) and current `plugin_methods` rows. If `api_namespace count: 2`, Koha’s `InstallPlugins` delete-and-reinsert loop will fail on the second insert.

**DB-only check** (does not run Class::Inspector, but shows bad table state):

```bash
koha-mysql library -e "
SELECT plugin_method, COUNT(*) AS n
FROM plugin_methods
WHERE plugin_class='Koha::Plugin::DFLiddle::SecurePublisherCredentials'
GROUP BY plugin_method
HAVING n > 1;"
```

### Verify hook registration

```bash
koha-mysql library -e "SELECT plugin_method FROM plugin_methods WHERE plugin_class='Koha::Plugin::DFLiddle::SecurePublisherCredentials' ORDER BY plugin_method;"
```

Required for Plugins page enable/disable:

- `enable`
- `disable`

Required for staff/OPAC UI:

- `intranet_js`
- `intranet_head`
- `intranet_catalog_biblio_enhancements_toolbar_button`
- `opac_js`
- `opac_head`

Then hard-refresh detail pages and repeat smoke test **B** and **C**.

### Self-repair on load (v1.2.22+)

The plugin tries to insert missing hook rows when an enabled plugin instance loads (e.g. opening Tools). That does **not** help until something loads the plugin class; the SQL/script above is more reliable immediately after a bad upload.

## Log interpretation

### Plack (`/var/log/koha/library/plack-error.log`)

| Log line | Action |
|----------|--------|
| `Received QUIT`, `Sending children hup signal`, `Starman::Server starting` | Expected around upload when `plugins_restart` is on |
| `Duplicate entry … api_namespace` | Run [recovery](#recovery-missing-login-links); avoid full `install_plugins.pl` |
| `Template process failed: spc_i18n.inc` | Stale file from plugin ≤1.2.15; remove file or deploy ≥1.2.20 |
| `toolbar button error` / `SPC availability match error` | Note timestamp; check bib match and permissions |

### Apache (`/var/log/apache2/error.log`)

| Log line | Action |
|----------|--------|
| `caught SIGWINCH, shutting down gracefully` | Common during `koha-common` or Apache restart — not plugin-specific |

## Production cutover

1. Complete [MANUAL_TEST_PLAN.md](MANUAL_TEST_PLAN.md) on DEV
2. Build `.kpz` from the tagged release commit
3. Follow [Standard upgrade workflow](#standard-upgrade-workflow) on production
4. Keep this runbook (or the SQL block) available for the first prod upload
5. Enter credentials in **Tools**; remove any legacy clear-text publisher logins from other systems

## `plugins_restart` setting

| Setting | Upload behaviour |
|---------|------------------|
| `plugins_restart: 1` | Plack restarts during upload; **500 on redirect is common**; version on Plugins page is the truth |
| `plugins_restart: 0` | Koha warns that restart is manual; you must run `sudo koha-plack --restart library` after upload; 500 may still appear |

Either way, run the smoke test after Plack is up.

## Uploaded version does not change

`version:check` only compares **source** files (`package.json` and `.pm`). Koha displays whatever is on disk under `pluginsdir` after upload.

| Check | Command / action |
|-------|------------------|
| Built `.kpz` really contains new version | `npm run verify:kpz` (after `npm run build`) |
| You uploaded the fresh `dist/*.kpz` | Not an old Downloads copy or a GitHub Release from an earlier tag |
| Server files updated | `grep VERSION /var/lib/koha/library/plugins/Koha/Plugin/DFLiddle/SecurePublisherCredentials.pm` |
| Install ran | Plugins page version still old + server file old → upload may have failed (HTTP 500); check Plack log |
| Plack loaded new code | `sudo koha-plack --restart library` then hard-refresh Plugins home |

If the server `.pm` still shows the old version, the upload did not replace the plugin tree — rebuild, verify kpz, upload again, restart Plack.

## Related documentation

- [INSTALLATION.md](INSTALLATION.md) — prerequisites and first install
- [ARCHITECTURE.md](ARCHITECTURE.md) — technical overview (hooks, static assets, i18n)
- [NEXT.md](NEXT.md) — release checklist (operations before translations)
