#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const root = path.join(__dirname, '..');
const pkg = require(path.join(root, 'package.json'));
const kpzPath = path.join(root, 'dist', pkg.kpzFilename || 'koha-plugin-secure-publisher-logins.kpz');
const pmInZip = 'Koha/Plugin/DFLiddle/SecurePublisherCredentials.pm';

const requiredInZip = [
  pmInZip,
  'Koha/Plugin/DFLiddle/SecurePublisherCredentials/Constants.pm',
  'Koha/Plugin/DFLiddle/SecurePublisherCredentials/Controller.pm',
  'Koha/Plugin/DFLiddle/SecurePublisherCredentials/openapi.json',
  'Koha/Plugin/DFLiddle/SecurePublisherCredentials/staticapi.json',
  'Koha/Plugin/DFLiddle/SecurePublisherCredentials/js/spc-config.js',
  'Koha/Plugin/DFLiddle/SecurePublisherCredentials/js/spc-opac.js',
  'Koha/Plugin/DFLiddle/SecurePublisherCredentials/js/spc-staff.js',
  'Koha/Plugin/DFLiddle/SecurePublisherCredentials/css/spc.css',
];

function readZipEntry(entry) {
  return execSync(`unzip -p "${kpzPath}" "${entry}"`, {
    encoding: 'utf8',
    stdio: ['pipe', 'pipe', 'pipe'],
  });
}

if (!fs.existsSync(kpzPath)) {
  console.error(`Missing ${kpzPath} — run npm run build first`);
  process.exit(1);
}

for (const entry of requiredInZip) {
  try {
    readZipEntry(entry);
  } catch (err) {
    console.error(`Missing required file in kpz: ${entry}`);
    process.exit(1);
  }
}

let pm;
try {
  pm = readZipEntry(pmInZip);
} catch (err) {
  console.error(`Could not read ${pmInZip} from kpz: ${err.message}`);
  process.exit(1);
}

const match = pm.match(/our \$VERSION = '([^']+)';/);
if (!match) {
  console.error('Could not read $VERSION from .kpz');
  process.exit(1);
}

if (match[1] !== pkg.version) {
  console.error(
    `kpz version mismatch: package.json is ${pkg.version}, .kpz contains ${match[1]}`
  );
  process.exit(1);
}

console.log(`kpz OK: ${pkg.version} (${path.basename(kpzPath)})`);
console.log(`kpz entries checked: ${requiredInZip.length}`);
