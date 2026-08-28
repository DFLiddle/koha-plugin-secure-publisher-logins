#!/usr/bin/env node
'use strict';
/**
 * Restore "Suggest for purchase" msgid in po/catalogs.json and apply Koha-aligned
 * translations where known (opac-detail-sidebar.inc). Other locales keep concise
 * plugin translations.
 *
 * Run: node scripts/fix-suggest-for-purchase-i18n.mjs
 * Then: npm run i18n:po && npm run i18n:verify
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const catalogsPath = path.join(__dirname, '..', 'po', 'catalogs.json');

const MSGID = 'Suggest for purchase';
const OLD_MAKE_MSGID = 'Make a purchase suggestion';
const EMAIL_MSGID = 'Email your library';

/** Koha 24.11 opac-bootstrap: msgid "Suggest for purchase" (where translated) */
const KOHA_SUGGEST_FOR_PURCHASE = {
  'fr-CA': "Suggestion d'achat",
};

/** Concise plugin fallback per locale (msgid order index 4 in patch-opac-access-states) */
const CONCISE_SUGGEST_FOR_PURCHASE = {
  'id-ID': 'Usulkan untuk dibeli',
  'th-TH': 'แนะนำให้จัดซื้อ',
  'zh-Hans-CN': '建议采购',
  'zh-Hant-TW': '建議採購',
  'zh-CN': '建议采购',
  'zh-TW': '建議採購',
  'ca-ES': 'Suggerir per a la compra',
  'cs-CZ': 'Navrhnout k nákupu',
  'da-DK': 'Foreslå til køb',
  'es-ES': 'Sugerir para compra',
  'fi-FI': 'Ehdota hankittavaksi',
  'gl-ES': 'Suxerir para compra',
  'hr-HR': 'Predloži za nabavu',
  'hu-HU': 'Javaslat beszerzésre',
  'it-IT': 'Suggerisci per l\'acquisto',
  'nb-NO': 'Foreslå til kjøp',
  'nn-NO': 'Foreslå til kjøp',
  'nl-BE': 'Voorstellen om aan te schaffen',
  'nl-NL': 'Voorstellen om aan te schaffen',
  'pl-PL': 'Zaproponuj zakup',
  'pt-BR': 'Sugerir para compra',
  'pt-PT': 'Sugerir para compra',
  'ro-RO': 'Sugerați pentru achiziție',
  'ru-RU': 'Предложить к покупке',
  'sk-SK': 'Navrhnúť na nákup',
  'sl-SI': 'Predlagaj za nakup',
  'sv-SE': 'Föreslå för inköp',
  'tr-TR': 'Satın alma için öner',
  'uk-UA': 'Запропонувати до закупівлі',
  'cy-GB': 'Awgrymu ar gyfer prynu',
  'is-IS': 'Leggja til kaup',
  ar: 'اقترح للشراء',
  'el-GR': 'Πρόταση για αγορά',
  'he-IL': 'הצע לרכישה',
  'ja-JP': '購入を提案',
  'ko-KR': '구매 제안',
  'et-EE': 'Soovita ostmiseks',
  'lv-LV': 'Ieteikt iegādei',
  'bg-BG': 'Предложи за покупка',
  'sr-RS': 'Предложи за набавку',
  'fo-FO': 'Legg til keyp',
  eu: 'Iradoki erosketa',
};

function main() {
  const catalogs = JSON.parse(fs.readFileSync(catalogsPath, 'utf8'));

  for (const locale of Object.keys(catalogs)) {
    const cat = catalogs[locale];
    const fromMake = cat[OLD_MAKE_MSGID];
    const fromSuggest = cat[MSGID];

    delete cat[OLD_MAKE_MSGID];
    delete cat[EMAIL_MSGID];

    cat[MSGID] =
      KOHA_SUGGEST_FOR_PURCHASE[locale] ??
      fromSuggest ??
      fromMake ??
      CONCISE_SUGGEST_FOR_PURCHASE[locale];

    if (!cat[MSGID]) {
      throw new Error(`${locale}: no translation for "${MSGID}"`);
    }
  }

  fs.writeFileSync(catalogsPath, JSON.stringify(catalogs, null, 2) + '\n', 'utf8');
  console.log(`Fixed "${MSGID}" in ${Object.keys(catalogs).length} locale(s)`);
}

main();
