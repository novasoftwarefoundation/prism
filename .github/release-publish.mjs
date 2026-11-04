import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const run = (args, options = {}) => execFileSync('npm', args, { encoding: 'utf8', ...options });
const { distTag, packages } = JSON.parse(readFileSync(join(process.env.RUNNER_TEMP, 'prism-release.json'), 'utf8'));

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
    run(['publish', pack.tarball, '--access', 'public', '--tag', distTag,
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
