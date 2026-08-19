# Review map

Start at `Koha/Plugin/DFLiddle/SecurePublisherCredentials/Controller.pm` (REST) and `templates/tool_list.tt` (staff UI). The plugin class is metadata, install, and Koha hooks only.

## Files

| File | Role |
|------|------|
| `SecurePublisherCredentials.pm` | Metadata, install/upgrade, hooks, thin `tool()` |
| `Tool.pm` | Staff Tools CRUD |
| `Controller.pm` | REST: availability, view, health |
| `Matcher.pm` | Match bib `856$u` domains to credentials |
| `Access.pm` | Who can view or manage |
| `Credentials.pm` / `Credential.pm` | Persistence and encryption |
| `AccessLogs.pm` | Audit log and retention |
| `Health.pm` | Deployment prerequisite checks |
| `Constants.pm` | Plugin name, labels, API path (keep `js/spc-config.js` in sync) |
| `js/spc-staff.js` / `js/spc-opac.js` | Detail-page modal and links |
| `js/spc-tool-form.js` | Tools form access-scope submit |
| `js/spc-config.js` | JS copy of API path and view label |

## Koha hooks

| Hook | Purpose |
|------|---------|
| `cronjob_nightly` | Purge access log |
| `intranet_head` / `intranet_js` | Staff CSS/JS |
| `opac_head` / `opac_js` | OPAC CSS/JS |
| `intranet_catalog_biblio_enhancements_toolbar_button` | Staff detail toolbar |
| `tool` | Dispatches to `Tool.pm` |
| `api_namespace` / `api_routes` / `static_routes` | REST and static files |

## REST

Prefix: `/api/v1/contrib/secure_publisher_credentials`

- `GET /biblios/{biblionumber}/availability`
- `GET /biblios/{biblionumber}/view`
- `GET /health`
- `GET /static/...` — JS and CSS (`staticapi.json`)
