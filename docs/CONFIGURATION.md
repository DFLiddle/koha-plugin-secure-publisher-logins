# Configuration Guide

## koha-conf.xml

| Setting | Required value |
|---------|----------------|
| `<enable_plugins>1</enable_plugins>` | Plugins enabled |
| `<plugins_restricted>0</plugins_restricted>` | Allows admin UI upload (optional but recommended for ease) |
| `<encryption_key>` | Non-empty; **must match** between prod and dev if you restore DB snapshots |

After editing:

```bash
sudo systemctl restart apache2
```

## System preferences

| Preference | Purpose |
|------------|---------|
| **ERMModule** | Enable ERM (recommended; plugin works via Tools if ERM UI embedding unavailable) |
| **AnonymousPatron** | Valid `borrowernumber` used in anonymized OPAC access logs |

`UseKohaPlugins` was removed in Koha 20.05; plugin enable/disable is per-plugin on the Plugins page.

## Staff permissions

| Role | Permissions |
|------|-------------|
| Patron | Standard OPAC login |
| Circulation / view-only staff | No `erm` — can use **View login info** on records in scope |
| Cataloguing / ERM staff | `erm` plus **report** and **tool** (needed for Tools plugin page) |
| Superlibrarian | Full access including **All libraries** credentials |

Assign permissions: **Staff → [user] → More → Set permissions**.

## Plugin credential fields

| Field | Notes |
|-------|-------|
| Publisher name | Display label |
| Domains | Comma-separated registrable domains (e.g. `example.com`, `journal.example.org`) |
| Accessible by | All / Specific library / Library group / None (inactive) |
| Patron note | Shown in modal to patrons and staff |
| Staff note | Shown only in staff modal |

## Nightly log purge (1100 days)

No separate cron script is required. The plugin registers Koha's C<cronjob_nightly> hook. On standard Koha packages, C<plugins_nightly.pl> is already run from C</etc/cron.daily/koha-common>:

```bash
koha-foreach --chdir --enabled /usr/share/koha/bin/cronjobs/plugins_nightly.pl
```

When the plugin is **enabled**, that job purges access log rows older than **1100 days** (~3 years).

If you previously added a custom line for C<purge_secure_publisher_credentials_log.pl>, you can remove it after upgrading to v1.2.5+.

### Verify the nightly hook on a server

**Prerequisite:** Upload and enable plugin **v1.2.5+** (earlier versions have no `cronjob_nightly` hook).

Run only this plugin's nightly task:

```bash
sudo koha-shell library -c '/usr/share/koha/bin/cronjobs/plugins_nightly.pl -m name="Secure Publisher Logins"'
```

If your Koha package installs cron scripts under `misc/cronjobs` instead of `bin/cronjobs`, adjust the path accordingly.

**Expected output** (when the hook runs):

```text
Secure Publisher Logins: purged 0 access log entries older than 1100 days.
```

`purged 0` is normal when no rows are older than 1100 days.

**If you see no output at all**, check:

1. Plugin is **enabled** on Administration → Plugins
2. `enable_plugins` is `1` in `koha-conf.xml`
3. The uploaded plugin is v1.2.5+ (re-upload `.kpz` and run `install_plugins.pl` if unsure)
4. Koha may log cron output to the action log when **CronjobLog** is enabled, rather than printing to your terminal

### Test purge without waiting 1100 days

Production retention stays at 1100 days. On **dev**, use the helper script shipped with the plugin (after v1.2.5 is installed):

```bash
# Adjust if your instance name is not library
SPC_BIN=/var/lib/koha/library/plugins/Koha/Plugin/DFLiddle/SecurePublisherCredentials/bin/spc_log_purge.pl
```

**1. Create an artificially old log row** (adjust database name if needed):

```bash
sudo koha-shell library -c "mysql koha_library -e \"
  INSERT INTO koha_plugin_dfliddle_securepublishercredentials_access_log
    (credential_id, borrowernumber, action, logged_on)
  SELECT NULL, borrowernumber, 'view', DATE_SUB(NOW(), INTERVAL 1200 DAY)
  FROM borrowers LIMIT 1;
\""
```

**2. Dry-run with a 30-day test window:**

```bash
sudo koha-shell library -c "perl /var/lib/koha/library/plugins/Koha/Plugin/DFLiddle/SecurePublisherCredentials/bin/spc_log_purge.pl --dry-run --days 30"
```

**3. Purge with the test window:**

```bash
sudo koha-shell library -c "perl /var/lib/koha/library/plugins/Koha/Plugin/DFLiddle/SecurePublisherCredentials/bin/spc_log_purge.pl --days 30"
```

**4. Confirm** dry-run now reports `0` and recent log entries remain.

The nightly hook always uses 1100 days. The helper script is for manual/testing use only; it is not added to system cron.

## Health warnings

Open **Tools → Tool plugins → Secure Publisher Logins**. Red banner lists blocking issues (missing encryption key, invalid AnonymousPatron, etc.). Resolve before expecting OPAC links to appear.

## Removing legacy clear-text credentials

Manually remove old credentials from Koha **Pages** and **HTML customizations** after verifying the plugin works. No import tool is provided in v1.
