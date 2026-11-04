import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, readFileSync, mkdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

// Exercise the real orchestration with a stub npm; these tests cannot reach a registry.
function scenario(mode, distTag = 'latest') {
  const dir = mkdtempSync(join(tmpdir(), 'prism-release-test-'));
  try {
    mkdirSync(join(dir, 'bin'));
    writeFileSync(join(dir, 'prism-release.json'), JSON.stringify({ distTag, packages:
      ['web', 'react'].map((name) => ({ name, version: '1.2.3', shasum: 'expected', tarball: name })) }));
    writeFileSync(join(dir, 'bin', 'npm'), `#!${process.execPath}
import fs from 'node:fs';
import path from 'node:path';
const dir = process.env.RUNNER_TEMP;
const args = process.argv.slice(2);
fs.appendFileSync(path.join(dir, 'calls'), JSON.stringify(args) + '\\n');
const name = args[1].split('@')[0];
if (args[0] === 'publish') {
  fs.writeFileSync(path.join(dir, name), 'accepted');
} else if (process.env.MODE === 'network') {
  console.log(JSON.stringify({error: {code: 'E503'}})); process.exit(1);
} else if (process.env.MODE === 'new' && !fs.existsSync(path.join(dir, name))) {
  console.log(JSON.stringify({error: {code: 'E404'}})); process.exit(1);
} else {
  console.log(JSON.stringify({shasum: process.env.MODE === 'mismatch' ? 'different' : 'expected'}));
}
`, { mode: 0o755 });
    const result = spawnSync(process.execPath, [resolve('.github/release-publish.mjs')], {
      encoding: 'utf8', env: { ...process.env, MODE: mode, RUNNER_TEMP: dir,
        PATH: `${join(dir, 'bin')}:${process.env.PATH}` }, timeout: 5000,
    });
    let calls;
    try { calls = readFileSync(join(dir, 'calls'), 'utf8').trim().split('\n').map(JSON.parse); }
    catch { throw new Error(result.stderr || String(result.error)); }
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
  assert.deepEqual(result.calls.map((args) => args.slice(0, 2)), [
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
