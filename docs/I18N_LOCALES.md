# Internationalization locales

This plugin ships runtime PO catalogs under `Koha/Plugin/DFLiddle/SecurePublisherCredentials/po/`. Koha 24.11 does not install plugin PO files into core locales (Bug 37472), so `I18N.pm` loads these files directly.

## Locale sources

Locales fall into three groups:

| Group | Criteria | Locales |
|-------|----------|---------|
| **Existing** | Hand-maintained in repo | `de-DE`, `fr-FR` |
| **Site** | Required for this installation | `id-ID`, `th-TH`, `zh-Hans-CN`, `zh-Hant-TW`, `zh-CN`, `zh-TW` |
| **Koha Weblate** | Koha 24.11 languages with >66% completion on [translate.koha-community.org](https://translate.koha-community.org/projects/koha/) | `ca-ES`, `cs-CZ`, `da-DK`, `es-ES`, `fi-FI`, `fr-CA`, `gl-ES`, `hr-HR`, `hu-HU`, `it-IT`, `nb-NO`, `nn-NO`, `nl-BE`, `nl-NL`, `pl-PL`, `pt-BR`, `pt-PT`, `ro-RO`, `ru-RU`, `sk-SK`, `sl-SI`, `sv-SE`, `tr-TR`, `uk-UA`, `cy-GB`, `is-IS`, `ar`, `el-GR`, `he-IL`, `ja-JP`, `ko-KR`, `et-EE`, `lv-LV`, `bg-BG`, `sr-RS`, `fo-FO`, `eu` |

`zh-CN` uses the same strings as `zh-Hans-CN`; `zh-TW` uses the same strings as `zh-Hant-TW`.

## Catalog workflow

1. **Source data** — `po/catalogs.json` maps locale code → `{ msgid: msgstr }` for every translatable string (master list from `de-DE.po`).
2. **Generate** — `scripts/generate-po-catalogs.mjs` reads the catalog JSON and writes `{locale}.po` files. It validates that each locale has every master msgid before writing.
3. **Verify** — `scripts/verify-po-catalogs.js` checks that every `po/*.po` file has the same msgid set as `de-DE.po`.

`de-DE.po` and `fr-FR.po` are not overwritten by `i18n:po`; they remain hand-edited references. Edit `po/catalogs.json` for generated locales, then run `npm run i18n:po`.

## Koha Weblate language list

`scripts/list-weblate-languages.sh` queries the Koha Weblate API and prints locales with `translated_percent` above a threshold (default 66):

```bash
chmod +x scripts/list-weblate-languages.sh
./scripts/list-weblate-languages.sh
./scripts/list-weblate-languages.sh 75
```

If bash reports `$'\r': command not found`, the script has Windows line endings. From the repo root in WSL:

```bash
sed -i 's/\r$//' scripts/list-weblate-languages.sh
```

(`.gitattributes` enforces LF for `*.sh` on checkout.)

## npm scripts

| Script | Command | Purpose |
|--------|---------|---------|
| `i18n:po` | `node scripts/generate-po-catalogs.mjs` | Generate PO files from `po/catalogs.json` |
| `i18n:verify` | `node scripts/verify-po-catalogs.js` | Verify all PO files match master msgids |

Example:

```bash
npm run i18n:po
npm run i18n:verify
```

## Adding a locale

1. Add translations for all msgids to `po/catalogs.json` (or extend `scripts/build-catalogs-json.mjs` and rebuild).
2. Run `npm run i18n:po`.
3. Run `npm run i18n:verify`.
4. Ensure the locale is enabled in Koha (`StaffInterfaceLanguages` / `OPACLanguages`).

## Master msgid list

The canonical msgid list is `de-DE.po` (49 strings). When adding new UI strings in code, update `de-DE.po` and `fr-FR.po`, run `node scripts/patch-opac-access-states-i18n.mjs` or extend `po/catalogs.json`, add entries to `catalogs.json` for every generated locale, then regenerate and verify.

For **Suggest for purchase**, use the Koha OPAC actions-menu msgid (`opac-detail-sidebar.inc`). Prefer Koha core translations where they exist (e.g. de `Zur Anschaffung vorschlagen`, fr `Suggestion d'achat`); otherwise add a concise plugin translation. Run `npm run i18n:fix-suggest` after correcting `po/catalogs.json`.
