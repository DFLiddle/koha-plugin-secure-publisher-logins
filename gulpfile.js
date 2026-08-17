const gulp = require('gulp');
const zip = require('gulp-zip');
const replace = require('gulp-replace');
const path = require('path');

const pm_name = 'SecurePublisherCredentials';
const pm_file = pm_name + '.pm';
const pm_class = 'Koha::Plugin::DFLiddle::' + pm_name;
const pm_file_path = path.join('Koha', 'Plugin', 'DFLiddle');

const pkg = require('./package.json');

function build_kpz() {
  const kpzName = pkg.kpzFilename || 'koha-plugin-secure-publisher-logins.kpz';
  return gulp.src([
    pm_file_path + '/**',
    '!' + pm_file_path + '/**/node_modules/**',
  ], { base: '.' })
    .pipe(replace('{VERSION}', pkg.version))
    .pipe(zip(kpzName))
    .pipe(gulp.dest('dist'));
}

exports.build = build_kpz;
exports.default = build_kpz;
