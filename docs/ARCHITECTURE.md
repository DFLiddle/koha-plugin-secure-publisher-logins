# Secure Publisher Credentials — Architecture Summary

**Plugin namespace:** `Koha::Plugin::DFLiddle::SecurePublisherCredentials`  
**Target Koha:** 24.11 LTS and later  
**Instance name:** `library`

## Purpose

Securely store shared publisher login credentials (encrypted at rest), match them to bibliographic records via `856$u` registrable domains, and expose them to authenticated patrons and staff through OPAC and staff detail pages.

## High-level components

```
┌─────────────────────────────────────────────────────────────────┐
│                         Koha 24.11+                              │
├─────────────────────────────────────────────────────────────────┤
│  OPAC (opac-detail.pl)          Staff (detail.pl / erm.pl)       │
│       │                                │                         │
│       │ opac_head hook (JS)            │ toolbar hook + tool()   │
│       ▼                                ▼                         │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │     Plugin REST API  /api/v1/contrib/secure_publisher_...    │   │
│  └──────────────────────────────────────────────────────────┘   │
│       │                                │                         │
│       ▼                                ▼                         │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────┐   │
│  │ Credential  │  │ AccessLog    │  │ Koha::Encryption      │   │
│  │ (Koha::Obj) │  │ (Koha::Obj)  │  │ (koha-conf.xml key)   │   │
│  └─────────────┘  └──────────────┘  └─────────────────────┘   │
│       │                                                          │
│       ▼                                                          │
│  plugin-owned MySQL tables (via get_qualified_table_name)        │
└─────────────────────────────────────────────────────────────────┘
```

## Integration choices

| Area | Approach | Rationale |
|------|----------|-----------|
| OPAC action link | `opac_head` hook + JavaScript inserts link into `#ulactioncontainer ul#action` | [Bug 26890](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=26890) OPAC toolbar hooks not in 24.11 |
| Staff toolbar | `intranet_catalog_biblio_enhancements_toolbar_button` | Native Koha hook on `detail.pl` |
| Credential management | `tool()` plugin page (Tools → Tool plugins) with ERM-style navigation link | ERM native embedding is heavy; spec allows Tools fallback |
| Data access | Koha::Object subclasses + `Koha::Database->dbh` | Modern Koha plugin practice |
| Encryption | `Koha::Encryption` (`encrypt_hex` / `decrypt_hex`) | Uses `<encryption_key>` from koha-conf.xml |
| Auth for API | Koha REST OAuth2 / session; patron OPAC cookie session | Standard plugin API auth |

## Matching logic

1. Extract host from each `856$u` on the bib (MARC record).
2. Derive **registrable domain** (eTLD+1) via `Domain.pm` helper (PSL-aware when `Net::PublicSuffix` available, heuristic fallback).
3. Match credential if any configured domain equals the extracted registrable domain.
4. Viewer must pass access scope: home library, library group membership, or `all`.
5. Inactive credentials excluded from detail pages; visible only in management UI.
6. If **multiple** credentials match, select the **most restrictive** scope: `library` (1) beats `library_group` (2) beats `all` (3).

## Permissions

| Action | Patron | Staff (no erm) | Staff (erm) | Superlibrarian |
|--------|--------|----------------|-------------|----------------|
| View login on detail | own scope | own scope | own scope | all |
| Manage login button | — | hidden | own scope | all |
| CRUD credentials | — | — | own library/group | all incl. "All" |
| View audit log | — | — | own library/group | all |

## Deployment health checks

When prerequisites fail (`AnonymousPatron` invalid, `encryption_key` missing, etc.), OPAC controls stay hidden and staff see a warning on the plugin tool page.

## Log retention

Daily cron invokes `misc/cronjobs/purge_secure_publisher_credentials_log.pl` (1100 days).

## Out of scope (v1)

Automated login, ERM entity linking, DNS validation, import/export, migration tooling.
