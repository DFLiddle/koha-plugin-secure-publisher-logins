# Server and Koha Prerequisites

Complete this checklist on **each** Koha instance (`library` on production and development).

## Configuration file (`/etc/koha/sites/library/koha-conf.xml`)

- [ ] `<enable_plugins>1</enable_plugins>`
- [ ] `<plugins_restricted>0</plugins_restricted>` (for upload via staff UI)
- [ ] `<encryption_key>` is present and non-empty
- [ ] Production and development use the **same** encryption key if DB is copied between them

## System preferences

- [ ] **ERMModule** = Enable
- [ ] **AnonymousPatron** = valid `borrowernumber` (patron record exists)
- [ ] At least one **superlibrarian** account exists

## Staff setup

- [ ] Staff who manage credentials have **erm** permission
- [ ] Those staff also have **report** and **tool** permissions (for Tools plugin access)

## Server

- [ ] Apache/Plack restarted after koha-conf changes
- [ ] HTTPS on OPAC and staff URLs
- [ ] Daily cron can run log purge script (see CONFIGURATION.md)

## Optional but recommended

- [ ] `Net::PublicSuffix` CPAN module for accurate eTLD+1 extraction (plugin falls back to heuristic)
- [ ] Dev instance (`dev.teamwork-global.net`) for testing before production deploy

## Post-install verification

```bash
# On Koha server — adjust path to your instance
sudo koha-shell library -c "perl -MKoha::Plugin::DFLiddle::SecurePublisherCredentials::Health -e 'use Data::Dumper; print Dumper(Koha::Plugin::DFLiddle::SecurePublisherCredentials::Health->check)'"
```

Expect `ok => 1` with empty `errors`.
