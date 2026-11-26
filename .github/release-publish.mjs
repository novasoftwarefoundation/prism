import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { releaseVersion } from './release-version.mjs';

// Publishes the packages release-prepare.mjs made for the tag RELEASE_TAG, from the folder
// NPM_PACKAGES that holds them and their manifest, prism-release.json. RELEASE_JSON is the
// release job's release.json, from the GitHub release: the folder must hold exactly the files
// it names, each with its sha256, for RELEASE_TAG at RELEASE_COMMIT, before the manifest is
// read. Values inside the folder can't vouch for the folder.
const dir = process.env.NPM_PACKAGES;
const run = (args, options = {}) => execFileSync('npm', args, { encoding: 'utf8', ...options });
const sha = (algorithm, file) => createHash(algorithm).update(readFileSync(join(dir, file))).digest('hex');

const anchor = JSON.parse(readFileSync(process.env.RELEASE_JSON, 'utf8'));
assert.equal(anchor.tag, process.env.RELEASE_TAG, `release.json is not ${process.env.RELEASE_TAG}'s`);
assert.equal(anchor.commit, process.env.RELEASE_COMMIT, `release.json is not of ${process.env.RELEASE_COMMIT}`);
assert.deepEqual(readdirSync(dir).toSorted(), Object.keys(anchor.npm ?? {}).toSorted(), 'The packages are not the files release.json names');
for (const [file, sha256] of Object.entries(anchor.npm)) {
  assert.equal(sha('sha256', file), sha256, `${file} is not the file the release job checked`);
}

const { version, distTag, packages } = JSON.parse(readFileSync(join(dir, 'prism-release.json'), 'utf8'));
assert.equal(version, releaseVersion(process.env.RELEASE_TAG).version, `The packages are not ${process.env.RELEASE_TAG}'s`);

// Every tarball is the one the manifest names, before anything is published.
for (const pack of packages) {
  assert.equal(sha('sha1', pack.tarball), pack.shasum, `${pack.tarball} is not the prepared package`);
}

function published(pack) {
  try {
    return JSON.parse(run(['view', `${pack.name}@${pack.version}`, 'dist', '--json', '--prefer-online',
      '--registry=https://registry.npmjs.org/'], { stdio: ['ignore', 'pipe', 'pipe'] }));
  } catch (error) {
    let response;
    try { response = JSON.parse(error.stdout); } catch { throw error; }
    if (response.error?.code === 'E404') return null;
    throw error;
  }
}

for (const pack of packages) {
  let remote = published(pack);
  if (!remote) {
    run(['publish', join(dir, pack.tarball), '--access', 'public', '--tag', distTag,
      '--registry=https://registry.npmjs.org/'], { stdio: 'inherit' });
    // npm can accept HTTP 202 before the version is visible. Do not submit it again.
    for (let attempt = 0; attempt < 60; attempt++) {
      remote = published(pack);
      if (remote) break;
      await new Promise((done) => setTimeout(done, 10000));
    }
    assert(remote, `${pack.name} is still processing; check npm before retrying`);
  }
  assert.equal(remote.shasum, pack.shasum, 'Existing npm version differs from the prepared package');
  console.log(`${pack.name}@${pack.version} verified`);
}
