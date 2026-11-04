import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { releaseVersion, checkVersions, checkFiles } from './release-version.mjs';

const { version, distTag } = releaseVersion(process.env.RELEASE_TAG);
const readJson = (file) => JSON.parse(readFileSync(file, 'utf8'));
checkVersions(version, readFileSync('design/mix.exs', 'utf8'),
  readJson('targets/web/package.json'), readJson('targets/react/package.json'));
const packages = [];
for (const target of ['web', 'react']) {
  const [pack] = JSON.parse(execFileSync('npm', ['pack', '--json', '--pack-destination', process.env.RUNNER_TEMP],
    { cwd: `targets/${target}`, encoding: 'utf8' }));
  checkFiles(readFileSync(`.github/npm-files${target === 'react' ? '-react' : ''}.txt`, 'utf8'),
    pack.files.map((file) => file.path));
  packages.push({ name: pack.name, version: pack.version, shasum: pack.shasum,
    tarball: join(process.env.RUNNER_TEMP, pack.filename) });
}
writeFileSync(join(process.env.RUNNER_TEMP, 'prism-release.json'), JSON.stringify({ version, distTag, packages }));
