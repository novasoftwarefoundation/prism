import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, readFileSync, mkdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';

// Exercise the real orchestration with a stub npm; these tests cannot reach a registry.
// Each tarball's bytes are its name; a swapped one has other bytes than its manifest's sha1.
function scenario(mode, distTag = 'latest', { tag = 'v1.2.3', swapped } = {}) {
  const dir = mkdtempSync(join(tmpdir(), 'prism-release-test-'));
  try {
    mkdirSync(join(dir, 'bin'));
    const sha1 = (bytes) => createHash('sha1').update(bytes).digest('hex');
    for (const name of ['web', 'react']) writeFileSync(join(dir, name), name === swapped ? 'another package' : name);
    writeFileSync(join(dir, 'prism-release.json'), JSON.stringify({ version: '1.2.3', distTag, packages:
      ['web', 'react'].map((name) => ({ name, version: '1.2.3', shasum: sha1(name), tarball: name })) }));
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
      encoding: 'utf8', env: { ...process.env, MODE: mode, RUNNER_TEMP: dir, NPM_PACKAGES: dir, RELEASE_TAG: tag,
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
test('a tarball swapped for another package stops the release before npm runs', () => {
  const result = scenario('new', 'latest', { swapped: 'react' });
  assert.notEqual(result.status, 0);
  assert.deepEqual(result.calls, []);
  assert.match(result.stderr, /react is not the prepared package/);
});
test('the packages of another version than the tag\'s are not published', () => {
  const result = scenario('new', 'latest', { tag: 'v1.2.4' });
  assert.notEqual(result.status, 0);
  assert.deepEqual(result.calls, []);
  assert.match(result.stderr, /not v1\.2\.4's/);
});
