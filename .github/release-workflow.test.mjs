// Third-party build trees stay out of jobs that can publish: the Webflow Designer
// Extension's npm packages (Webflow's CLI, ~700 of them) run only in a job that can
// read, and the release job takes its zip as data (ADR 0014); the Kotlin library's
// Gradle build (the Android Gradle plugin, Kotlin's and their plugins) runs only in a job
// with no secret, and the job that signs and uploads it takes its bundle as data (ADR
// 0015). The workflows are read with a YAML parser, and what the guard can't classify
// counts against it.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { posix } from 'node:path';
import { test } from 'node:test';
import { parse } from 'yaml';

const workflows = ['.github/workflows/release.yml', '.github/workflows/ci.yml'];

// A `permissions` value: a level for every scope (`write-all`, `read-all`) or an
// object of scopes; undefined without one. Anything else (an expression, a null, an
// unknown level) is "unknown", which counts as able to write.
function permissions(value) {
  if (value === undefined) return undefined;
  if (value === 'write-all' || value === 'read-all') return value;
  const isScopes =
    typeof value === 'object' && value !== null && !Array.isArray(value) &&
    Object.values(value).every((level) => ['read', 'write', 'none'].includes(level));
  return isScopes ? value : 'unknown';
}

// A step's folder, normalized (`./targets/webflow/` is `targets/webflow`); "unknown"
// when it isn't a plain path, such as an expression.
function folderOf(value, otherwise) {
  if (value === undefined) return otherwise;
  if (typeof value !== 'string' || value.includes('${{')) return 'unknown';
  return posix.normalize(value).replace(/\/$/, '');
}

// The jobs of a workflow, each with its permissions (or the workflow's; without either,
// the repository's default, which may write) and its steps, each with its folder.
function jobs(yaml) {
  const workflow = parse(yaml);
  const top = permissions(workflow.permissions) ?? 'unknown';
  return Object.entries(workflow.jobs ?? {}).map(([name, job]) => {
    const folder = folderOf(job.defaults?.run?.['working-directory'], '.');
    const steps = (job.steps ?? []).map((step) => ({ ...step, folder: folderOf(step['working-directory'], folder) }));
    const needs = [].concat(job.needs ?? []);
    return {
      name,
      permissions: permissions(job.permissions) ?? top,
      steps,
      env: job.env ?? {},
      needs,
      outputs: job.outputs ?? {},
      // The job as written, and the workflow's own environment, which every job has.
      raw: job,
      workflowEnv: workflow.env ?? {},
    };
  });
}

const canWrite = ({ permissions }) =>
  typeof permissions === 'string' ? permissions !== 'read-all' : Object.values(permissions).includes('write');
// A step that runs npm (or Webflow's CLI) in the extension's folder, or in a folder
// the guard can't read.
const runsWebflowPackages = ({ run, folder }) =>
  typeof run === 'string' &&
  /\bnpm\b|\bnpx\b|\bwebflow\b /.test(run) &&
  (folder === 'targets/webflow' || folder === 'unknown' || /targets\/webflow/.test(run));

// The jobs of a workflow that can write and run the extension's npm packages.
const writersRunningWebflow = (yaml) =>
  jobs(yaml).filter((job) => canWrite(job) && job.steps.some(runsWebflowPackages)).map(({ name }) => name);

test('no job that can write runs the Webflow Designer Extension\'s npm packages', () => {
  for (const file of workflows) assert.deepEqual(writersRunningWebflow(readFileSync(file, 'utf8')), [], file);
});

test('the release builds the Webflow bundle in a job that can only read, and the release job needs it', () => {
  const release = jobs(readFileSync('.github/workflows/release.yml', 'utf8'));
  const builders = release.filter((job) => job.steps.some(runsWebflowPackages));
  assert.deepEqual(builders.map(({ name, permissions }) => [name, permissions]), [['webflow', { contents: 'read' }]]);
  const publisher = release.find(({ permissions }) => permissions['id-token'] === 'write');
  assert.ok(
    publisher.steps.some(({ uses, with: inputs }) =>
      uses?.startsWith('actions/download-artifact@') && inputs?.name === 'prism-tokens-webflow'),
    'the publishing job downloads the bundle',
  );
});

// The release's webflow job, edited: its permissions block replaced, or any text.
const release = readFileSync('.github/workflows/release.yml', 'utf8');
const block = '    permissions:\n      contents: read\n    defaults:';
const withPermissions = (written) => release.replace(block, `${written}\n    defaults:`);
const edited = (yaml, from, to) => {
  assert.equal(yaml.split(from).length, 2, `one ${JSON.stringify(from)}`);
  return yaml.replace(from, to);
};

test('the guard catches the release\'s webflow job given write access in any form', () => {
  assert.equal(release.split(block).length, 2, "the webflow job's permissions block");
  for (const written of [
    '    permissions: write-all',
    '    permissions: { contents: write, id-token: write }',
    '    permissions:\n      contents: write',
    '    permissions: ${{ fromJSON(inputs.permissions) }}',
  ]) {
    assert.deepEqual(writersRunningWebflow(withPermissions(written)), ['webflow'], written);
  }
  // Without its own block, the job has the workflow's; without that, the default's.
  const inherits = release.replace(block, '    defaults:');
  assert.deepEqual(writersRunningWebflow(inherits), [], 'the workflow reads');
  const noTop = edited(inherits, 'permissions:\n  contents: read\n\nconcurrency:', 'concurrency:');
  assert.deepEqual(writersRunningWebflow(noTop), ['webflow'], 'no top-level block');
});

// YAML layouts of the webflow job given write access, which the guard must read as such.
const layouts = () => ({
    'a blank line in its permissions block': withPermissions('    permissions:\n      contents: read\n\n      id-token: write'),
    'a lower-indented comment in its permissions block': withPermissions(
      '    permissions:\n      contents: read\n    # publish\n      id-token: write',
    ),
    'a comment at the start of a line in its permissions block': withPermissions(
      '    permissions:\n# publish\n      contents: write',
    ),
    'a comment on its job key': edited(withPermissions('    permissions: write-all'), '\n  webflow:\n', '\n  webflow: # bundle\n'),
    'a comment on the jobs key': edited(withPermissions('    permissions: write-all'), '\njobs:\n', '\njobs: # the release\n'),
    "a comment on its step's working-directory": edited(
      edited(withPermissions('    permissions: write-all'), '    defaults:\n      run:\n        working-directory: targets/webflow\n', ''),
      '      - name: Bundle the Webflow Designer Extension\n',
      '      - name: Bundle the Webflow Designer Extension\n        working-directory: targets/webflow # the extension\n',
    ),
    'a quoted job key': edited(withPermissions('    permissions: write-all'), '\n  webflow:\n', '\n  "webflow":\n'),
    "a quoted step's working-directory": edited(
      edited(withPermissions('    permissions: write-all'), '    defaults:\n      run:\n        working-directory: targets/webflow\n', ''),
      '      - name: Bundle the Webflow Designer Extension\n',
      '      - name: Bundle the Webflow Designer Extension\n        working-directory: "targets/webflow"\n',
    ),
  "its steps listed at the steps key's indent": (() => {
    const yaml = withPermissions('    permissions: write-all');
    const start = yaml.indexOf('    steps:\n', yaml.indexOf('\n  webflow:\n'));
    const end = yaml.indexOf('\n  release:\n');
    return yaml.slice(0, start) + yaml.slice(start, end).replace(/\n {6}/g, '\n    ') + yaml.slice(end);
  })(),
});

for (const layout of Object.keys(layouts())) {
  test(`the guard catches the webflow job given write access, with ${layout}`, () => {
    assert.deepEqual(writersRunningWebflow(layouts()[layout]), ['webflow']);
  });
}

test('the reader sees a job\'s permissions, its default folder and a step\'s own folder', () => {
  const [build, publish] = jobs(`permissions:
  contents: read

jobs:
  build:
    defaults:
      run:
        working-directory: targets/webflow
    steps:
      - run: npm ci
  publish:
    permissions:
      contents: write
      id-token: write
    steps:
      - name: Bundle
        working-directory: ./targets/webflow/
        run: npm run bundle
`);
  assert.deepEqual(build.permissions, { contents: 'read' });
  assert.equal(runsWebflowPackages(build.steps[0]), true);
  assert.equal(canWrite(build), false);
  assert.deepEqual(publish.permissions, { contents: 'write', 'id-token': 'write' });
  assert.equal(runsWebflowPackages(publish.steps[0]), true);
  assert.equal(canWrite(publish), true);
});

test('the reader sees permissions on one line, and counts what it can\'t read as writing', () => {
  const job = (value) => jobs(`jobs:\n  build:\n    permissions: ${value}\n    steps:\n      - run: npm ci\n`)[0];
  assert.equal(job('write-all').permissions, 'write-all');
  assert.equal(canWrite(job('write-all')), true);
  assert.equal(canWrite(job('read-all')), false);
  assert.deepEqual(job('{ contents: write, id-token: write }').permissions, { contents: 'write', 'id-token': 'write' });
  assert.equal(canWrite(job('{ contents: write, id-token: write }')), true);
  assert.equal(canWrite(job('{ contents: read }')), false);
  assert.equal(canWrite(job('{}')), false);
  assert.equal(canWrite(job('${{ inputs.permissions }}')), true);
  assert.equal(canWrite(job('{ contents: admin }')), true);
  // No permissions anywhere: the repository's default token, which may write.
  assert.equal(canWrite(jobs('jobs:\n  build:\n    steps:\n      - run: npm ci\n')[0]), true);
  // npm in a folder the guard can't read counts as the extension's.
  const [step] = jobs('jobs:\n  build:\n    steps:\n      - working-directory: ${{ inputs.dir }}\n        run: npm ci\n')[0].steps;
  assert.equal(runsWebflowPackages(step), true);
});

// A job that reads a secret anywhere: in the workflow's environment, which every job has, or
// anywhere in the job (its environment, its container's or services' credentials and
// environment, a step, `secrets: inherit`).
const readsSecrets = (job) =>
  /\bsecrets\b/.test(JSON.stringify(job.workflowEnv)) || /\bsecrets\b/.test(JSON.stringify(job.raw));
// A step that runs the Kotlin build or sets up its toolchain: Gradle, a JDK, the Android SDK,
// or the bundle's build.
const runsKotlinBuild = ({ run, uses }) =>
  (typeof uses === 'string' && /^(actions\/setup-java|gradle\/|android-actions\/)/.test(uses)) ||
  (typeof run === 'string' && /\bgradlew?\b|\bsdkmanager\b|\bjava\b|kotlin-release\.sh[^\n]*--bundle/.test(run));

// The jobs of a workflow that read a secret and run the Kotlin build.
const secretHoldersRunningKotlin = (yaml) =>
  jobs(yaml).filter((job) => readsSecrets(job) && job.steps.some(runsKotlinBuild)).map(({ name }) => name);

test('no job that reads a secret runs the Kotlin library\'s Gradle build or its toolchain', () => {
  for (const file of workflows) assert.deepEqual(secretHoldersRunningKotlin(readFileSync(file, 'utf8')), [], file);
});

// The release's Kotlin jobs: maven-bundle, with read access and no secret, builds the
// bundle, uploads it and gives the artifact's id and the bundle's digest as its outputs;
// maven-central downloads that artifact by its id, not by a name another job of the run could
// upload under, and its release step gets the digest, which the script checks before it signs.
function checkKotlinRelease(yaml) {
  const jobsOf = jobs(yaml);
  const builders = jobsOf.filter((job) => job.steps.some(runsKotlinBuild));
  assert.deepEqual(
    builders.map(({ name, permissions }) => [name, permissions]),
    [['maven-bundle', { contents: 'read' }]],
  );
  const [bundle] = builders;
  const upload = bundle.steps.find(({ uses }) => uses?.startsWith('actions/upload-artifact@'));
  assert.equal(upload?.with?.name, 'prism-compose-bundle', 'the bundle job uploads the bundle');
  assert.equal(bundle.outputs['artifact-id'], `\${{ steps.${upload.id}.outputs.artifact-id }}`, 'the bundle job gives its artifact id');
  const digest = bundle.steps.find(({ run }) => /kotlin-release\.sh --digest /.test(run ?? ''));
  assert.ok(digest?.id, 'the bundle job takes the bundle\'s digest');
  assert.equal(bundle.outputs.sha256, `\${{ steps.${digest.id}.outputs.sha256 }}`, 'the bundle job gives the digest');

  const publisher = jobsOf.find(({ name }) => name === 'maven-central');
  assert.deepEqual(publisher.permissions, { contents: 'read' });
  assert.ok(publisher.needs.includes('maven-bundle'), 'maven-central needs the bundle job');
  assert.ok(readsSecrets(publisher), 'maven-central holds the Maven secrets');
  const download = publisher.steps.find(({ uses }) => uses?.startsWith('actions/download-artifact@'));
  assert.equal(download?.with?.['artifact-ids'], '${{ needs.maven-bundle.outputs.artifact-id }}', 'maven-central downloads the bundle by its id');
  assert.equal(download.with.name, undefined, 'maven-central downloads by id, not by name');
  const releasing = publisher.steps.find(({ run }) =>
    /kotlin-release\.sh "\$RELEASE_TAG" "\$RUNNER_TEMP\/prism-compose-bundle"/.test(run ?? ''));
  assert.ok(releasing, 'maven-central releases the downloaded bundle');
  assert.equal(releasing.env?.MAVEN_BUNDLE_SHA256, '${{ needs.maven-bundle.outputs.sha256 }}', 'the release step gets the bundle job\'s digest');
}

test('the release builds the Kotlin bundle without secrets, and the job that signs it takes that bundle as data', () => {
  checkKotlinRelease(release);
});

// The release, edited so maven-central could sign a bundle another job put in maven-bundle's
// place: each edit must fail the check.
for (const [layout, from, to] of [
  [
    'the bundle downloaded by name',
    '          artifact-ids: ${{ needs.maven-bundle.outputs.artifact-id }}\n          merge-multiple: true\n',
    '          name: prism-compose-bundle\n',
  ],
  ['no digest given to the release step', '          MAVEN_BUNDLE_SHA256: ${{ needs.maven-bundle.outputs.sha256 }}\n', ''],
  ['no digest among the bundle job\'s outputs', '      sha256: ${{ steps.digest.outputs.sha256 }}\n', ''],
  ['no artifact id among the bundle job\'s outputs', '      artifact-id: ${{ steps.upload.outputs.artifact-id }}\n', ''],
]) {
  test(`the check refuses a Kotlin release with ${layout}`, () => {
    const yaml = edited(release, from, to);
    assert.throws(() => checkKotlinRelease(yaml), assert.AssertionError);
  });
}

// The release, edited so a job with the Maven secrets builds the library, in each way the
// guard must see; each edit is made in its test, so a release without the jobs fails there.
const signing = '      - name: Sign and upload the Kotlin library to Maven Central\n';
const bundleEnv = '      RELEASE_TAG: ${{ github.ref_name }}\n      GRADLE: "9.9.2"\n';
const bundleJob = '  maven-bundle:\n    needs: checks\n';
for (const [layout, edit] of Object.entries({
  'a Gradle run in maven-central': () =>
    edited(release, signing, `      - run: gradle -p targets/kotlin assemble\n${signing}`),
  'the bundle built in maven-central': () =>
    edited(release, signing, `      - run: .github/kotlin-release.sh --bundle 1.0.0 out\n${signing}`),
  'a JDK set up in maven-central': () =>
    edited(release, signing, `      - uses: actions/setup-java@d1374f8ac74474200d16ef8ecee22c7ae7a51880\n${signing}`),
  'a Maven secret in the bundle job': () =>
    edited(release, bundleEnv, `      KEY: \${{ secrets.MAVEN_SIGNING_KEY }}\n${bundleEnv}`),
  'all secrets in the bundle job\'s environment': () =>
    edited(release, bundleEnv, `      ALL: \${{ toJSON(secrets) }}\n${bundleEnv}`),
  'a secret in the workflow\'s environment': () =>
    edited(release, '\nconcurrency:\n', '\nenv:\n  KEY: ${{ secrets.MAVEN_SIGNING_KEY }}\n\nconcurrency:\n'),
  'a secret in the bundle job\'s container': () =>
    edited(
      release,
      bundleJob,
      `${bundleJob}    container:\n      image: ghcr.io/example/android\n      credentials:\n        username: x\n        password: \${{ secrets.MAVEN_CENTRAL_PASSWORD }}\n`,
    ),
  'a secret in the bundle job\'s services': () =>
    edited(
      release,
      bundleJob,
      `${bundleJob}    services:\n      cache:\n        image: redis\n        env:\n          KEY: \${{ secrets.MAVEN_SIGNING_KEY }}\n`,
    ),
})) {
  test(`the guard catches a job with secrets running the Kotlin build, with ${layout}`, () => {
    assert.notDeepEqual(secretHoldersRunningKotlin(edit()), [], layout);
  });
}
