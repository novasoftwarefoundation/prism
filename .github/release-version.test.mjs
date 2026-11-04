import { test } from 'node:test';
import assert from 'node:assert/strict';
import { releaseVersion, checkVersions, checkFiles } from './release-version.mjs';

test('stable releases use latest and release candidates use next', () => {
  assert.deepEqual(releaseVersion('v1.2.3'), { version: '1.2.3', distTag: 'latest' });
  assert.deepEqual(releaseVersion('v1.2.3-rc.0'), { version: '1.2.3-rc.0', distTag: 'next' });
});
test('refuse malformed release tags', () => {
  for (const tag of ['1.2.3', 'v01.2.3', 'v1.2', 'v1.2.3-rc.01', 'v1.2.3\n']) {
    assert.throws(() => releaseVersion(tag));
  }
});
test('design, packages and React peer versions all match', () => {
  const web = { name: 'kit', version: '1.2.3' };
  const react = { version: '1.2.3', peerDependencies: { kit: '1.2.3' } };
  checkVersions('1.2.3', 'version: "1.2.3"', web, react);
  for (const [design, w, r] of [
    ['version: "1.2.2"', web, react],
    ['version: "1.2.3"', { ...web, version: '1.2.2' }, react],
    ['version: "1.2.3"', web, { ...react, version: '1.2.2' }],
    ['version: "1.2.3"', web, { ...react, peerDependencies: { kit: '1.2.2' } }],
  ]) assert.throws(() => checkVersions('1.2.3', design, w, r));
});
test('reject extra or missing package files', () => {
  checkFiles('LICENSE\nindex.js\n', ['index.js', 'LICENSE']);
  assert.throws(() => checkFiles('LICENSE\nindex.js\n', ['index.js']));
  assert.throws(() => checkFiles('LICENSE\nindex.js\n', ['index.js', 'LICENSE', '.env']));
});
