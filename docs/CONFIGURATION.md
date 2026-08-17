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

## Cron — log purge (1100 days)

Install the purge script and call it daily. Example line in `/etc/cron.daily/koha-common`:

```bash
/usr/share/koha/misc/cronjobs/purge_secure_publisher_credentials_log.pl
```

Copy from this repository’s `misc/cronjobs/purge_secure_publisher_credentials_log.pl` into your Koha `misc/cronjobs/` tree on each server.

## Health warnings

Open **Tools → Tool plugins → Secure Publisher Credentials**. Red banner lists blocking issues (missing encryption key, invalid AnonymousPatron, etc.). Resolve before expecting OPAC links to appear.

## Removing legacy clear-text credentials

Manually remove old credentials from Koha **Pages** and **HTML customizations** after verifying the plugin works. No import tool is provided in v1.
