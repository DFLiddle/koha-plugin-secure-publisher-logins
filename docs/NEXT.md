# Next

Pick up after the v1.2.x feedback batch (on `main`).

## 1. Troubleshoot translations (not working)

`po/de-DE.po` and `po/fr-FR.po` exist, but switching OPAC (or staff) to German/French still shows English **View login info** (and likely the other strings).

Likely causes to check first:

- Labels are English constants (`Constants.pm`, `js/spc-config.js`) and are never passed through Koha gettext / `[% t() %]`.
- Templates and toolbar HTML use those constants or hard-coded English, so a `.po` file on disk is not enough.
- Plugin `.po` files may also never be compiled/installed into Koha’s locale path (the files themselves say to install with Koha translation tools).

See `docs/MANUAL_TEST_PLAN.md` (i18n section) for the intended check.

## 2. Release v1.3.0

When you are ready to ship this batch: bump version to **1.3.0**, tag, let GitHub Actions attach the `.kpz`. Do not tag until translations are either fixed or explicitly deferred.
