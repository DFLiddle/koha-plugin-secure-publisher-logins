# Database Schema

Tables are created in the plugin `install()` method using `$self->get_qualified_table_name()`.

For `Koha::Plugin::DFLiddle::SecurePublisherCredentials`:

| Logical name | Physical table name |
|--------------|---------------------|
| credentials | `koha_plugin_dfliddle_securepublishercredentials_credentials` |
| access_log | `koha_plugin_dfliddle_securepublishercredentials_access_log` |

## credentials

| Column | Type | Notes |
|--------|------|-------|
| id | INT AUTO_INCREMENT PK | |
| publisher_name | VARCHAR(255) NOT NULL | Display name |
| domains | TEXT NOT NULL | Comma-separated registrable domains |
| username | VARCHAR(255) NOT NULL | Stored plain (not secret at rest policy — password encrypted) |
| password_encrypted | TEXT NOT NULL | `Koha::Encryption->encrypt_hex` |
| access_scope_type | ENUM('all','library','library_group','inactive') | "Accessible by" |
| access_scope_code | VARCHAR(80) NULL | branchcode or library_group id |
| staff_note | TEXT NULL | Staff-only in modal |
| patron_note | TEXT NULL | Shown to patrons and staff |
| date_created | TIMESTAMP DEFAULT CURRENT_TIMESTAMP | |
| date_modified | TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | |

**Unique constraint:** `(publisher_name, access_scope_type, access_scope_code)` — rejects duplicates on save.

**Index:** `domains` is not indexed (match via application logic after domain extraction from bib).

## access_log

| Column | Type | Notes |
|--------|------|-------|
| id | BIGINT AUTO_INCREMENT PK | |
| credential_id | INT NULL | FK logical to credentials.id |
| borrowernumber | INT NOT NULL | AnonymousPatron for OPAC views; real staff id for staff actions |
| action | ENUM('view','create','update','delete') | |
| biblionumber | INT NULL | Set for view actions from detail pages |
| logged_on | TIMESTAMP DEFAULT CURRENT_TIMESTAMP | |

**Index:** `(logged_on)` for purge job.

**Retention:** 1100 days (`AccessLogs::RETENTION_DAYS`). Purged by the plugin `cronjob_nightly` hook via `plugins_nightly.pl`.

## plugin_data keys

| Key | Purpose |
|-----|---------|
| `__INSTALLED__` | Set by Koha on install |
| `__INSTALLED_VERSION__` | Schema version tracking |
| `__ENABLED__` | Plugin enabled flag |
