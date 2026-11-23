import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { releaseVersion, checkVersions, checkFiles } from './release-version.mjs';

// The packages and their manifest, prism-release.json, go into NPM_PACKAGES, an existing
// folder: the release hands that folder on, and release-publish.mjs publishes from it.
const out = process.env.NPM_PACKAGES;
const { version, distTag } = releaseVersion(process.env.RELEASE_TAG);
const readJson = (file) => JSON.parse(readFileSync(file, 'utf8'));
checkVersions(version, readFileSync('design/mix.exs', 'utf8'),
  readJson('targets/web/package.json'), readJson('targets/react/package.json'));
const packages = [];
for (const target of ['web', 'react']) {
  const [pack] = JSON.parse(execFileSync('npm', ['pack', '--json', '--pack-destination', out],
    { cwd: `targets/${target}`, encoding: 'utf8' }));
  checkFiles(readFileSync(`.github/npm-files${target === 'react' ? '-react' : ''}.txt`, 'utf8'),
    pack.files.map((file) => file.path));
  packages.push({ name: pack.name, version: pack.version, shasum: pack.shasum,
    tarball: pack.filename });
}
writeFileSync(join(out, 'prism-release.json'), JSON.stringify({ version, distTag, packages }));
