#!/usr/bin/env node
'use strict';

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, '..');
const catalogsPath = path.join(root, 'po', 'catalogs.json');
const poDir = path.join(
  root,
  'Koha',
  'Plugin',
  'DFLiddle',
  'SecurePublisherCredentials',
  'po'
);
const masterPoPath = path.join(poDir, 'de-DE.po');

const LOCALE_LABELS = {
  'id-ID': 'Indonesian',
  'th-TH': 'Thai',
  'zh-Hans-CN': 'Chinese (Simplified)',
  'zh-Hant-TW': 'Chinese (Traditional)',
  'zh-CN': 'Chinese (Simplified)',
  'zh-TW': 'Chinese (Traditional)',
  'ca-ES': 'Catalan',
  'cs-CZ': 'Czech',
  'da-DK': 'Danish',
  'es-ES': 'Spanish',
  'fi-FI': 'Finnish',
  'fr-CA': 'French (Canada)',
  'gl-ES': 'Galician',
  'hr-HR': 'Croatian',
  'hu-HU': 'Hungarian',
  'it-IT': 'Italian',
  'nb-NO': 'Norwegian Bokmål',
  'nn-NO': 'Norwegian Nynorsk',
  'nl-BE': 'Dutch (Belgium)',
  'nl-NL': 'Dutch',
  'pl-PL': 'Polish',
  'pt-BR': 'Portuguese (Brazil)',
  'pt-PT': 'Portuguese',
  'ro-RO': 'Romanian',
  'ru-RU': 'Russian',
  'sk-SK': 'Slovak',
  'sl-SI': 'Slovenian',
  'sv-SE': 'Swedish',
  'tr-TR': 'Turkish',
  'uk-UA': 'Ukrainian',
  'cy-GB': 'Welsh',
  'is-IS': 'Icelandic',
  ar: 'Arabic',
  'el-GR': 'Greek',
  'he-IL': 'Hebrew',
  'ja-JP': 'Japanese',
  'ko-KR': 'Korean',
  'et-EE': 'Estonian',
  'lv-LV': 'Latvian',
  'bg-BG': 'Bulgarian',
  'sr-RS': 'Serbian',
  'fo-FO': 'Faroese',
  eu: 'Basque',
};

function parsePoMsgids(poText) {
  const msgids = [];
  const re = /^msgid\s+"((?:\\.|[^"\\])*)"\s*$/gm;
  let m;
  while ((m = re.exec(poText)) !== null) {
    const id = unescapePo(m[1]);
    if (id !== '') msgids.push(id);
  }
  return msgids;
}

function unescapePo(s) {
  return s.replace(/\\n/g, '\n').replace(/\\"/g, '"');
}

function escapePo(s) {
  return s.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n');
}

function readMasterMsgids() {
  const text = fs.readFileSync(masterPoPath, 'utf8');
  const msgids = parsePoMsgids(text);
  if (msgids.length === 0) {
    throw new Error(`No msgids found in master PO: ${masterPoPath}`);
  }
  return msgids;
}

function poHeader(locale) {
  const label = LOCALE_LABELS[locale] || locale;
  return [
    `# ${label} translations for Secure Publisher Logins`,
    '# Applied at runtime from this file (Koha 24.11 does not install plugin PO files).',
    '',
  ].join('\n');
}

function writePo(locale, entries, masterMsgids) {
  const lines = [poHeader(locale)];
  for (const msgid of masterMsgids) {
    lines.push(`msgid "${escapePo(msgid)}"`);
    lines.push(`msgstr "${escapePo(entries[msgid] ?? '')}"`);
    lines.push('');
  }
  const outPath = path.join(poDir, `${locale}.po`);
  fs.writeFileSync(outPath, lines.join('\n'), 'utf8');
  return outPath;
}

function validateCatalog(locale, entries, masterMsgids) {
  const missing = masterMsgids.filter((id) => !entries[id] || entries[id] === '');
  if (missing.length) {
    throw new Error(
      `Locale ${locale} missing ${missing.length} msgid(s): ${missing.slice(0, 3).join(', ')}${missing.length > 3 ? '…' : ''}`
    );
  }
  const extra = Object.keys(entries).filter((id) => !masterMsgids.includes(id));
  if (extra.length) {
    console.warn(`Locale ${locale} has ${extra.length} extra msgid(s) not in master list`);
  }
}

function main() {
  if (!fs.existsSync(catalogsPath)) {
    throw new Error(`Missing catalogs file: ${catalogsPath}`);
  }
  const catalogs = JSON.parse(fs.readFileSync(catalogsPath, 'utf8'));
  const masterMsgids = readMasterMsgids();
  const locales = Object.keys(catalogs).sort();
  const written = [];

  for (const locale of locales) {
    const entries = catalogs[locale];
    if (!entries || typeof entries !== 'object') {
      throw new Error(`Invalid catalog entry for locale ${locale}`);
    }
    validateCatalog(locale, entries, masterMsgids);
    const outPath = writePo(locale, entries, masterMsgids);
    written.push({ locale, path: outPath });
  }

  console.log(`Master msgids: ${masterMsgids.length}`);
  console.log(`Generated ${written.length} PO file(s):`);
  for (const { locale } of written) {
    console.log(`  ${locale}`);
  }
}

main();
