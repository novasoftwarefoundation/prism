// The Kotlin release signs only the bundle maven-bundle built: .github/kotlin-release.sh
// compares the bundle's digest with MAVEN_BUNDLE_SHA256, that job's output, before it checks
// the bundle or imports the key (ADR 0015). It runs here in a repository of its own, at a tag,
// with stand-ins for the secrets, and with `gpg` and `curl` that only note that they ran, so
// nothing is signed or sent anywhere.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { chmodSync, copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { test } from 'node:test';

const version = '9.9.9';
const files = [
  '.github/kotlin-release.sh',
  '.github/maven-files.txt',
  'targets/kotlin/build.gradle.kts',
  'targets/kotlin/gradle.properties',
  'targets/kotlin/settings.gradle.kts',
];

const temp = (name) => mkdtempSync(join(tmpdir(), `kotlin-release-${name}-`));
const git = (dir, ...args) => {
  const result = spawnSync('git', args, { cwd: dir, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
};

// A repository with the script and the library's coordinates, at the tag v9.9.9.
function repository() {
  const dir = temp('repo');
  for (const file of files) {
    mkdirSync(dirname(join(dir, file)), { recursive: true });
    copyFileSync(file, join(dir, file));
  }
  mkdirSync(join(dir, 'design'));
  writeFileSync(join(dir, 'design/mix.exs'), `      version: "${version}",\n`);
  git(dir, 'init', '-q');
  git(dir, '-c', 'user.name=t', '-c', 'user.email=t@example.org', 'add', '.');
  git(dir, '-c', 'user.name=t', '-c', 'user.email=t@example.org', 'commit', '-qm', 'Prism');
  git(dir, 'tag', `v${version}`);
  return dir;
}

const hash = (algorithm, bytes) => createHash(algorithm).update(bytes).digest('hex');

// A bundle outside the repository: every file of .github/maven-files.txt, each file's checksums
// as Central asks for them.
function writeFile(bundle, path, bytes) {
  writeFileSync(join(bundle, path), bytes);
  writeFileSync(join(bundle, `${path}.md5`), `${hash('md5', bytes)}\n`);
  writeFileSync(join(bundle, `${path}.sha1`), `${hash('sha1', bytes)}\n`);
}

// A POM with the fields Central requires.
const pom = `<project>
  <groupId>org.novasoftwarefoundation</groupId>
  <artifactId>prism-compose</artifactId>
  <version>${version}</version>
  <name>Prism</name>
  <description>Prism</description>
  <url>https://github.com/novasoftwarefoundation/prism</url>
  <licenses><license><name>MIT</name></license></licenses>
  <developers><developer><name>Nova</name></developer></developers>
  <scm><connection>scm:git:https://github.com/novasoftwarefoundation/prism.git</connection></scm>
</project>
`;

function bundle() {
  const dir = temp('bundle');
  const paths = readFileSync('.github/maven-files.txt', 'utf8').replaceAll('VERSION', version).split('\n');
  for (const path of paths.filter((path) => path && !/\.(md5|sha1)$/.test(path))) {
    mkdirSync(dirname(join(dir, path)), { recursive: true });
    writeFile(dir, path, path.endsWith('.pom') ? pom : `the file ${path}\n`);
  }
  return dir;
}

// `gpg` and `curl` that note their run in `ran` and fail, as if nothing could be signed or
// found.
function standIns() {
  const bin = temp('bin');
  const ran = join(bin, 'ran');
  for (const tool of ['gpg', 'curl']) {
    writeFileSync(join(bin, tool), `#!/bin/sh\necho ${tool} >> "${ran}"\nexit 22\n`);
    chmodSync(join(bin, tool), 0o755);
  }
  return { bin, ran };
}

function release(dir, bundleDir, env = {}) {
  const { bin, ran } = standIns();
  const result = spawnSync('sh', ['.github/kotlin-release.sh', `v${version}`, bundleDir], {
    cwd: dir,
    encoding: 'utf8',
    env: {
      ...process.env,
      PATH: `${bin}:${process.env.PATH}`,
      MAVEN_CENTRAL_USERNAME: 'username',
      MAVEN_CENTRAL_PASSWORD: 'password',
      MAVEN_SIGNING_KEY: 'key',
      MAVEN_SIGNING_KEY_PASSWORD: 'passphrase',
      ...env,
    },
  });
  return { ...result, ran: existsSync(ran) ? readFileSync(ran, 'utf8').trim().split('\n') : [] };
}

const digest = (dir, bundleDir) => {
  const result = spawnSync('sh', ['.github/kotlin-release.sh', '--digest', bundleDir], { cwd: dir, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trim();
};

const aar = `org/novasoftwarefoundation/prism-compose/${version}/prism-compose-${version}.aar`;

test('the digest is the bundle\'s: it changes with a file\'s bytes, and only then', () => {
  const dir = repository();
  const bundleDir = bundle();
  const before = digest(dir, bundleDir);
  assert.match(before, /^[0-9a-f]{64}$/);
  assert.equal(digest(dir, bundleDir), before);
  writeFile(bundleDir, aar, 'another library\n');
  assert.notEqual(digest(dir, bundleDir), before);
});

test('the digest of a folder that isn\'t there fails, and prints no digest', () => {
  const dir = repository();
  const result = spawnSync('sh', ['.github/kotlin-release.sh', '--digest', join(temp('gone'), 'bundle')], {
    cwd: dir,
    encoding: 'utf8',
  });
  assert.equal(result.status, 1);
  assert.equal(result.stdout, '');
  assert.match(result.stderr, /is no folder/);
});

test('a bundle put in place of maven-bundle\'s, with checksums of its own, is not signed', () => {
  const dir = repository();
  const bundleDir = bundle();
  const built = digest(dir, bundleDir);
  // Another job's bundle: every file and checksum as Central asks for them, so --check passes.
  writeFile(bundleDir, aar, 'another library\n');

  const result = release(dir, bundleDir, { MAVEN_BUNDLE_SHA256: built });
  assert.equal(result.status, 1, result.stdout);
  assert.match(result.stderr, /not maven-bundle's .*: not signing it/);
  assert.deepEqual(result.ran, [], 'gpg and curl never ran');
});

test('without maven-bundle\'s digest, nothing is signed', () => {
  const dir = repository();
  const result = release(dir, bundle());
  assert.equal(result.status, 1, result.stdout);
  assert.match(result.stderr, /MAVEN_BUNDLE_SHA256 is not set/);
  assert.deepEqual(result.ran, []);
});

test('the bundle maven-bundle built gets past the digest to the signing', () => {
  const dir = repository();
  const bundleDir = bundle();
  const result = release(dir, bundleDir, { MAVEN_BUNDLE_SHA256: digest(dir, bundleDir) });
  // The stand-ins find nothing on Central, then refuse the key: the digest let it through.
  assert.equal(result.status === 0, false);
  assert.doesNotMatch(result.stderr, /digest/);
  assert.ok(result.ran.includes('gpg'), `gpg ran: ${result.stderr}`);
});
