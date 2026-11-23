import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, readFileSync, mkdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';

// Exercise the real orchestration with a stub npm; these tests cannot reach a registry.
// Each tarball's bytes are its name. The packages folder is the Release run's artifact, and
// release.json, beside it, the release job's digests of it from the GitHub release. `edit`
// changes the folder after release.json was written (as a swapped artifact would), and
// `edited` before (as if the release job had checked those files).
const commit = 'f652d710aabcd806e1bc1e0f9d9aa362ff27a32e';
const hash = (algorithm, bytes) => createHash(algorithm).update(bytes).digest('hex');
const sha1 = (bytes) => hash('sha1', bytes);
const manifest = (distTag, bytesOf) => JSON.stringify({ version: '1.2.3', distTag, packages:
  ['web', 'react'].map((name) => ({ name, version: '1.2.3', shasum: sha1(bytesOf(name)), tarball: name })) });

function scenario(mode, distTag = 'latest', { tag = 'v1.2.3', edit, edited, anchor = (json) => json } = {}) {
  const dir = mkdtempSync(join(tmpdir(), 'prism-release-test-'));
  try {
    mkdirSync(join(dir, 'bin'));
    const packages = join(dir, 'packages');
    mkdirSync(packages);
    const write = (file, bytes) => writeFileSync(join(packages, file), bytes);
    for (const name of ['web', 'react']) write(name, name);
    write('prism-release.json', manifest(distTag, (name) => name));
    edited?.(write);
    const npm = Object.fromEntries(['web', 'react', 'prism-release.json'].map((file) =>
      [file, hash('sha256', readFileSync(join(packages, file)))]));
    writeFileSync(join(dir, 'release.json'), JSON.stringify(anchor({ tag: 'v1.2.3', commit, mavenBundleSha256: '0'.repeat(64), npm })));
    edit?.(write);
    writeFileSync(join(dir, 'bin', 'npm'), `#!${process.execPath}
import fs from 'node:fs';
import path from 'node:path';
const dir = process.env.RUNNER_TEMP;
const args = process.argv.slice(2);
fs.appendFileSync(path.join(dir, 'calls'), JSON.stringify(args) + '\\n');
const name = path.basename(args[1]).split('@')[0];
if (args[0] === 'publish') {
  fs.writeFileSync(path.join(dir, name + '.published'), 'accepted');
} else if (process.env.MODE === 'network') {
  console.log(JSON.stringify({error: {code: 'E503'}})); process.exit(1);
} else if (process.env.MODE === 'new' && !fs.existsSync(path.join(dir, name + '.published'))) {
  console.log(JSON.stringify({error: {code: 'E404'}})); process.exit(1);
} else {
  console.log(JSON.stringify({shasum: process.env.MODE === 'mismatch' ? 'different' : process.env[name]}));
}
`, { mode: 0o755 });
    const result = spawnSync(process.execPath, [resolve('.github/release-publish.mjs')], {
      encoding: 'utf8', env: { ...process.env, MODE: mode, RUNNER_TEMP: dir, NPM_PACKAGES: packages, RELEASE_TAG: tag,
        RELEASE_COMMIT: commit, RELEASE_JSON: join(dir, 'release.json'),
        web: sha1('web'), react: sha1('react'),
        PATH: `${join(dir, 'bin')}:${process.env.PATH}` }, timeout: 5000,
    });
    let calls = [];
    try { calls = readFileSync(join(dir, 'calls'), 'utf8').trim().split('\n').map(JSON.parse); }
    catch { if (result.status === 0) throw new Error(result.stderr || String(result.error)); }
    return { ...result, calls };
  } finally { rmSync(dir, { recursive: true, force: true }); }
}

test('identical existing packages are verified without a second upload', () => {
  const result = scenario('existing');
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.calls.filter((args) => args[0] === 'publish').length, 0);
});
test('new uploads are checked for availability in web then React order', () => {
  const result = scenario('new', 'next');
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(result.calls.map(([command, what]) => [command, basename(what)]), [
    ['view', 'web@1.2.3'], ['publish', 'web'], ['view', 'web@1.2.3'],
    ['view', 'react@1.2.3'], ['publish', 'react'], ['view', 'react@1.2.3'],
  ]);
  for (const args of result.calls.filter((args) => args[0] === 'publish')) {
    assert.equal(args[args.indexOf('--tag') + 1], 'next');
  }
});
test('mismatched bytes stop the release before subsequent packages', () => {
  const result = scenario('mismatch');
  assert.notEqual(result.status, 0);
  assert.equal(result.calls.length, 1);
  assert.match(result.stderr, /Existing npm version differs/);
});
test('registry failures cannot be mistaken for an unpublished version', () => {
  const result = scenario('network');
  assert.notEqual(result.status, 0);
  assert.equal(result.calls.length, 1);
});
// The folder is checked against release.json from the GitHub release, never against the
// manifest inside it: a folder swapped whole, its manifest's sha1s matching its own tarballs,
// is still refused.
for (const [layout, options, refusal] of [
  ['a tarball swapped for another package', { edit: (write) => write('react', 'another package') },
    /react is not the file the release job checked/],
  ['the artifact swapped whole, its manifest matching its tarballs', {
    edit: (write) => {
      write('react', 'another package');
      write('prism-release.json', manifest('latest', (name) => (name === 'react' ? 'another package' : name)));
    },
  }, /is not the file the release job checked/],
  ['a file release.json doesn\'t name', { edit: (write) => write('extra.tgz', 'extra') }, /not the files release\.json names/],
  ['a file release.json names missing', { anchor: (json) => ({ ...json, npm: { ...json.npm, 'gone.tgz': '0'.repeat(64) } }) },
    /not the files release\.json names/],
  ['release.json of another tag', { anchor: (json) => ({ ...json, tag: 'v1.2.4' }) }, /release\.json is not v1\.2\.3's/],
  ['release.json of another commit', { anchor: (json) => ({ ...json, commit: '1'.repeat(40) }) }, /release\.json is not of f652d71/],
  ['release.json without npm digests', { anchor: ({ npm, ...json }) => json }, /not the files release\.json names/],
  ['a manifest whose sha1 is not its tarball\'s', { edited: (write) => write('react', 'another package') },
    /react is not the prepared package/],
  ['the packages of another version than the tag\'s', { tag: 'v1.2.4', anchor: (json) => ({ ...json, tag: 'v1.2.4' }) },
    /The packages are not v1\.2\.4's/],
]) {
  test(`${layout} stops the release before npm runs`, () => {
    const result = scenario('new', 'latest', options);
    assert.notEqual(result.status, 0);
    assert.deepEqual(result.calls, []);
    assert.match(result.stderr, refusal);
  });
}
