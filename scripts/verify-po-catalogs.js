#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const poDir = path.join(
  root,
  'Koha',
  'Plugin',
  'DFLiddle',
  'SecurePublisherCredentials',
  'po'
);
const masterPoPath = path.join(poDir, 'de-DE.po');

function unescapePo(s) {
  return s.replace(/\\n/g, '\n').replace(/\\"/g, '"');
}

function parsePoMsgids(poText) {
  const msgids = new Set();
  const re = /^msgid\s+"((?:\\.|[^"\\])*)"\s*$/gm;
  let m;
  while ((m = re.exec(poText)) !== null) {
    const id = unescapePo(m[1]);
    if (id !== '') msgids.add(id);
  }
  return msgids;
}

function main() {
  const masterText = fs.readFileSync(masterPoPath, 'utf8');
  const masterMsgids = parsePoMsgids(masterText);
  if (masterMsgids.size === 0) {
    console.error(`No msgids in master PO: ${masterPoPath}`);
    process.exit(1);
  }

  const poFiles = fs
    .readdirSync(poDir)
    .filter((f) => f.endsWith('.po'))
    .sort();

  let failed = false;
  console.log(`Master (de-DE.po): ${masterMsgids.size} msgids`);
  console.log(`Checking ${poFiles.length} PO file(s)…`);

  for (const file of poFiles) {
    const filePath = path.join(poDir, file);
    const text = fs.readFileSync(filePath, 'utf8');
    const msgids = parsePoMsgids(text);
    const missing = [...masterMsgids].filter((id) => !msgids.has(id));
    const extra = [...msgids].filter((id) => !masterMsgids.has(id));

    if (missing.length || extra.length) {
      failed = true;
      console.error(`FAIL ${file}: missing=${missing.length}, extra=${extra.length}`);
      if (missing.length) {
        console.error(`  missing: ${missing.join(', ')}`);
      }
      if (extra.length) {
        console.error(`  extra: ${extra.join(', ')}`);
      }
    } else {
      console.log(`OK   ${file}: ${msgids.size} msgids`);
    }
  }

  if (failed) {
    process.exit(1);
  }
  console.log('All PO catalogs match master msgid list.');
}

main();
