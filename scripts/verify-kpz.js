#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const root = path.join(__dirname, '..');
const pkg = require(path.join(root, 'package.json'));
const kpzPath = path.join(root, 'dist', pkg.kpzFilename || 'koha-plugin-secure-publisher-logins.kpz');
const pmInZip = 'Koha/Plugin/DFLiddle/SecurePublisherCredentials.pm';

if (!fs.existsSync(kpzPath)) {
  console.error(`Missing ${kpzPath} — run npm run build first`);
  process.exit(1);
}

let pm;
try {
  pm = execSync(`unzip -p "${kpzPath}" "${pmInZip}"`, { encoding: 'utf8' });
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
