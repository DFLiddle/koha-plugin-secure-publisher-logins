#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const pkg = require(path.join(root, 'package.json'));
const pmPath = path.join(
  root,
  'Koha',
  'Plugin',
  'DFLiddle',
  'SecurePublisherCredentials.pm'
);

const pm = fs.readFileSync(pmPath, 'utf8');
const match = pm.match(/our \$VERSION = '([^']+)';/);

if (!match) {
  console.error('Could not read $VERSION from SecurePublisherCredentials.pm');
  process.exit(1);
}

const pmVersion = match[1];
if (pmVersion !== pkg.version) {
  console.error(
    `Version mismatch: package.json is ${pkg.version}, SecurePublisherCredentials.pm is ${pmVersion}`
  );
  process.exit(1);
}

console.log(`Version OK: ${pkg.version}`);
