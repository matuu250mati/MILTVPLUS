import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  CATEGORY, buildMovieRow, downloadUrl, isOpenLicense, parseArgs, parseYear, pickVideoFiles,
} from './import_archive_catalog.mjs';

const MB = 1024 * 1024;

test('only open licences are accepted', () => {
  assert.equal(isOpenLicense('https://creativecommons.org/publicdomain/mark/1.0/'), true);
  assert.equal(isOpenLicense('http://creativecommons.org/publicdomain/zero/1.0/'), true);
  assert.equal(isOpenLicense('https://creativecommons.org/licenses/by/4.0/'), true);
  assert.equal(isOpenLicense('https://creativecommons.org/licenses/by-sa/3.0/'), true);
  assert.equal(isOpenLicense('https://creativecommons.org/licenses/by-nc/4.0/'), false);
  assert.equal(isOpenLicense('https://creativecommons.org/licenses/by-nd/4.0/'), false);
  assert.equal(isOpenLicense(undefined), false);
  assert.equal(isOpenLicense('all rights reserved'), false);
});

test('parseYear reads years from common metadata shapes', () => {
  assert.equal(parseYear('1922'), 1922);
  assert.equal(parseYear(['1931-05-01']), 1931);
  assert.equal(parseYear('unknown'), null);
});

test('pickVideoFiles prefers h.264 mp4 and skips trailers and tiny files', () => {
  const picked = pickVideoFiles([
    { name: 'film_trailer.mp4', format: 'h.264', size: '90000000' },
    { name: 'tiny.mp4', format: 'h.264', size: '1000' },
    { name: 'film.ogv', format: 'Ogg Video', size: '300000000' },
    { name: 'film_512kb.mp4', format: '512Kb MPEG4', size: '80000000' },
    { name: 'film.mp4', format: 'h.264', size: String(300 * MB) },
  ]);
  assert.deepEqual(picked.map((f) => f.name), ['film.mp4', 'film_512kb.mp4']);
});

test('downloadUrl encodes identifier and file name', () => {
  assert.equal(
    downloadUrl('night of the living dead', 'Night Of.mp4'),
    'https://archive.org/download/night%20of%20the%20living%20dead/Night%20Of.mp4',
  );
});

test('buildMovieRow produces a playable, separate "gratis" row', () => {
  const row = buildMovieRow({
    identifier: 'nosferatu',
    metadata: { title: 'Nosferatu', year: '1922', description: '<p>Classic</p>', licenseurl: 'https://creativecommons.org/publicdomain/mark/1.0/', subject: ['horror'] },
    files: [{ name: 'nosferatu.mp4', format: 'h.264', size: String(400 * MB), length: '5640.5' }],
    tmdb: { id: 653, title: 'Nosferatu', overview: 'Sinopsis', poster_path: '/p.jpg', backdrop_path: '/b.jpg' },
  });
  assert.equal(row.category, CATEGORY);
  assert.match(row.category.toLowerCase(), /gratis/);
  assert.equal(row.url_stream, 'https://archive.org/download/nosferatu/nosferatu.mp4');
  assert.deepEqual(row.stream_urls, [row.url_stream]);
  assert.equal(row.tmdb_id, 653);
  assert.equal(row.release_year, 1922);
  assert.equal(row.duration_seconds, 5641);
  assert.equal(row.is_published, true);
  assert.ok(row.genres.includes('Gratis'));
});

test('buildMovieRow falls back to archive.org art and returns null without video', () => {
  const row = buildMovieRow({
    identifier: 'x', metadata: { title: 'X', description: 'a' },
    files: [{ name: 'x.mp4', format: 'h.264', size: String(100 * MB) }], tmdb: null,
  });
  assert.equal(row.logo, 'https://archive.org/services/img/x');
  assert.equal(row.tmdb_id, null);
  assert.equal(buildMovieRow({ identifier: 'y', metadata: { title: 'Y' }, files: [] }), null);
});

test('parseArgs defaults to a safe dry run and clamps the limit', () => {
  assert.deepEqual(parseArgs([]), { limit: 25, out: 'archive_manifest.json', apply: false, idsFile: null });
  assert.equal(parseArgs(['--limit', '9999']).limit, 100);
  assert.equal(parseArgs(['--apply']).apply, true);
});
