# Secure Publisher Logins v1.2.24

**Date:** August 2026  
**Koha target:** 24.11

## Summary

Fixes **Disable** on the Plugins page when `plugin_methods` lacks `enable` / `disable` rows after a partial `InstallPlugins` run. Also guards REST availability/view when the plugin is disabled.

## Fixes

- Register `enable`, `disable`, `install`, `uninstall`, `upgrade` in hook self-heal and `spc_repair_plugin_methods.pl` (required by `Koha::Plugins::Handler` for Plugins UI).
- REST `availability` and `view` return empty/404 when `__ENABLED__` is not 1.
- `_plugin_enabled` treats stored `"0"` as disabled (not only undefined vs set).

## Documentation

- `OPERATIONS.md` — SQL recovery includes management methods; notes Disable failure symptom.

## Upgrade notes

If Disable did nothing on v1.2.23, run the updated repair script or SQL in `OPERATIONS.md`, then upload v1.2.24 so self-heal includes management methods on load.
