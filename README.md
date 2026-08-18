# Secure Publisher Logins — Koha Plugin

Secure storage and controlled sharing of publisher login credentials for e-resources, matched to bibliographic records via `856$u` registrable domains.

**Namespace:** `Koha::Plugin::DFLiddle::SecurePublisherCredentials`  
**Target:** Koha 24.11 LTS+  
**Author:** David F Liddle

## Install

Download the latest `.kpz` from **[Releases](https://github.com/DFLiddle/koha-plugin-secure-publisher-logins/releases)** and upload via **Administration → Plugins**.

Full steps: [docs/INSTALLATION.md](docs/INSTALLATION.md)

## Quick start (developers)

1. Complete [prerequisites](docs/PREREQUISITES.md)
2. Build: `npm ci && npm run build` → `dist/koha-plugin-secure-publisher-logins.kpz`
3. Install via **Administration → Plugins → Upload**
4. Manage logins: **Tools → Tool plugins → Secure Publisher Logins**
5. Follow [MANUAL_TEST_PLAN.md](docs/MANUAL_TEST_PLAN.md) on your dev instance first

## Documentation

| Document | Purpose |
|----------|---------|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Technical overview |
| [docs/DATABASE_SCHEMA.md](docs/DATABASE_SCHEMA.md) | Table definitions |
| [docs/INSTALLATION.md](docs/INSTALLATION.md) | Install steps |
| [docs/CONFIGURATION.md](docs/CONFIGURATION.md) | Koha settings |
| [docs/PREREQUISITES.md](docs/PREREQUISITES.md) | Server/Koha checklist |
| [docs/GITHUB_GUIDE.md](docs/GITHUB_GUIDE.md) | Repo and releases |
| [docs/MANUAL_TEST_PLAN.md](docs/MANUAL_TEST_PLAN.md) | Acceptance testing |

## Cron (log retention)

Add to `/etc/cron.daily/koha-common` on each server:

```bash
$KOHA_HOME/misc/cronjobs/purge_secure_publisher_credentials_log.pl
```

(Copy the script from this repo’s `misc/cronjobs/` into your Koha tree, or invoke by full path after plugin install.)

## License

GPL-3.0-or-later (consistent with Koha). See [LICENSE](LICENSE).
