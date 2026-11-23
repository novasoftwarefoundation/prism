// Third-party build trees stay out of jobs that can publish: the Webflow Designer
// Extension's npm packages (Webflow's CLI, ~700 of them) run only in a job that can
// read, and the release job takes its zip as data (ADR 0014); the Kotlin library's
// Gradle build (the Android Gradle plugin, Kotlin's and their plugins) runs only in a job
// with no secret, and the release job takes its bundle as data (ADR 0015). Release builds
// and publishes nothing but the GitHub release; each target is published by a workflow of
// its own, which publishes what one successful Release run of a version tag built, from that
// run's prism-release artifact. The workflows are read with a YAML parser, and what the
// guard can't classify counts against it.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { posix } from 'node:path';
import { test } from 'node:test';
import { parse } from 'yaml';

const publishers = {
  '.github/workflows/publish-npm.yml': { contents: 'read', actions: 'read', 'id-token': 'write' },
  '.github/workflows/publish-swift.yml': { contents: 'read', actions: 'read' },
  '.github/workflows/publish-maven-central.yml': { contents: 'read', actions: 'read' },
};
const workflows = ['.github/workflows/release.yml', '.github/workflows/ci.yml', ...Object.keys(publishers)];

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

// The release's webflow job, edited: its permissions block replaced, or any text.
const release = readFileSync('.github/workflows/release.yml', 'utf8');
const webflowOutputs =
  '    timeout-minutes: 15\n    outputs:\n      artifact-id: ${{ steps.upload.outputs.artifact-id }}\n' +
  '      sha256: ${{ steps.digest.outputs.sha256 }}\n';
const bundleOutputs =
  '    # artifacts too.\n    outputs:\n      artifact-id: ${{ steps.upload.outputs.artifact-id }}\n' +
  '      sha256: ${{ steps.digest.outputs.sha256 }}\n';
const block = '    permissions:\n      contents: read\n    defaults:';
const withPermissions = (written) => release.replace(block, `${written}\n    defaults:`);
const edited = (yaml, from, to) => {
  assert.equal(yaml.split(from).length, 2, `one ${JSON.stringify(from)}`);
  return yaml.replace(from, to);
};

// The release's Webflow hand-over: the webflow job, which can only read, builds the zip,
// uploads it and gives the artifact's id and the zip's sha256 as its outputs; the release
// job, the only one that can write, downloads that artifact by its id, not by a name another
// job of the run (maven-bundle's Gradle build) could upload under, and compares the zip's
// sha256 with the output before it attaches anything.
function checkWebflowRelease(yaml) {
  const jobsOf = jobs(yaml);
  const builders = jobsOf.filter((job) => job.steps.some(runsWebflowPackages));
  assert.deepEqual(builders.map(({ name, permissions }) => [name, permissions]), [['webflow', { contents: 'read' }]]);
  const [webflow] = builders;
  const upload = webflow.steps.find(({ uses }) => uses?.startsWith('actions/upload-artifact@'));
  assert.equal(upload?.with?.name, 'prism-tokens-webflow', 'the webflow job uploads the zip');
  assert.equal(webflow.outputs['artifact-id'], `\${{ steps.${upload.id}.outputs.artifact-id }}`, 'the webflow job gives its artifact id');
  const digest = webflow.steps.find(({ run }) => /openssl dgst -sha256 prism-tokens-webflow\.zip/.test(run ?? ''));
  assert.ok(digest?.id, 'the webflow job takes the zip\'s sha256');
  assert.equal(webflow.outputs.sha256, `\${{ steps.${digest.id}.outputs.sha256 }}`, 'the webflow job gives the sha256');

  assert.deepEqual(jobsOf.filter(canWrite).map(({ name }) => name), ['release'], 'only the release job can write');
  const publisher = jobsOf.find(({ name }) => name === 'release');
  assert.ok(publisher.needs.includes('webflow'), 'the release job needs the webflow job');
  const steps = publisher.steps;
  const download = steps.findIndex(({ uses, with: given }) =>
    uses?.startsWith('actions/download-artifact@') && given?.['artifact-ids'] === '${{ needs.webflow.outputs.artifact-id }}');
  assert.ok(download >= 0, 'the release job downloads the zip by its id');
  assert.equal(steps[download].with.name, undefined, 'the release job downloads by id, not by name');
  const compare = steps.findIndex(({ env, run }) =>
    env?.WEBFLOW_SHA256 === '${{ needs.webflow.outputs.sha256 }}' && /\$WEBFLOW_SHA256/.test(run ?? '') && /exit 1/.test(run ?? ''));
  assert.ok(compare > download, 'the release job compares the zip\'s sha256 with the webflow job\'s');
  const attaches = steps.findIndex(({ run }) => /gh release/.test(run ?? ''));
  assert.ok(attaches > compare, 'it compares before it attaches anything');
}

test('the release builds the Webflow bundle in a job that can only read, and the release job takes that zip as data', () => {
  checkWebflowRelease(release);
});

for (const [layout, from, to] of [
  [
    'the zip downloaded by name',
    '          artifact-ids: ${{ needs.webflow.outputs.artifact-id }}\n          merge-multiple: true\n',
    '          name: prism-tokens-webflow\n',
  ],
  ['no sha256 among the webflow job\'s outputs', webflowOutputs, webflowOutputs.replace(/      sha256: .*\n/, '')],
  ['no artifact id among the webflow job\'s outputs', webflowOutputs, webflowOutputs.replace(/      artifact-id: .*\n/, '')],
  [
    'no comparison of the zip\'s sha256',
    '          WEBFLOW_SHA256: ${{ needs.webflow.outputs.sha256 }}\n',
    '          OTHER: ${{ needs.webflow.outputs.sha256 }}\n',
  ],
]) {
  test(`the check refuses a Webflow release with ${layout}`, () => {
    const yaml = edited(release, from, to);
    assert.throws(() => checkWebflowRelease(yaml), assert.AssertionError);
  });
}

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
// GitHub reads a context's name in any case (`SECRETS.X`), so the guard does too.
const readsSecrets = (job) =>
  /\bsecrets\b/i.test(JSON.stringify(job.workflowEnv)) || /\bsecrets\b/i.test(JSON.stringify(job.raw));
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

// The Kotlin release: maven-bundle, with read access and no secret, builds the bundle, uploads
// it and gives the artifact's id and the bundle's digest as its outputs; the release job
// downloads that artifact by its id, not by a name another job of the run could upload under,
// compares its digest with maven-bundle's before it attaches or hands on anything, and writes
// that digest into release.json. publish-maven-central.yml, which holds the Maven secrets,
// takes the bundle from the Release run's prism-release artifact, and its release step gets
// release.json's digest, which the script checks before it signs.
function checkKotlinRelease(yaml, publishing) {
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

  const releaser = jobsOf.find(({ name }) => name === 'release');
  assert.ok(releaser.needs.includes('maven-bundle'), 'the release job needs the bundle job');
  const steps = releaser.steps;
  const download = steps.findIndex(({ uses, with: given }) =>
    uses?.startsWith('actions/download-artifact@') && given?.['artifact-ids'] === '${{ needs.maven-bundle.outputs.artifact-id }}');
  assert.ok(download >= 0, 'the release job downloads the bundle by its id');
  assert.equal(steps[download].with.name, undefined, 'the release job downloads by id, not by name');
  const compare = steps.findIndex(({ env, run }) =>
    env?.MAVEN_BUNDLE_SHA256 === '${{ needs.maven-bundle.outputs.sha256 }}' &&
    /kotlin-release\.sh --digest/.test(run ?? '') && /\$MAVEN_BUNDLE_SHA256/.test(run ?? '') && /exit 1/.test(run ?? ''));
  assert.ok(compare > download, 'the release job compares the bundle\'s digest with the bundle job\'s');
  const attaches = steps.findIndex(({ run }) => /gh release/.test(run ?? ''));
  const handsOn = steps.findIndex(({ uses, with: given }) => uses?.startsWith('actions/upload-artifact@') && given?.name === 'prism-release');
  assert.ok(attaches > compare && handsOn > compare, 'it compares before it attaches or hands on anything');
  const written = steps.find(({ run }) => /release\.json/.test(run ?? ''));
  assert.equal(written?.env?.MAVEN_BUNDLE_SHA256, '${{ needs.maven-bundle.outputs.sha256 }}', 'release.json holds the bundle job\'s digest');

  const [publisher] = jobs(publishing);
  assert.ok(readsSecrets(publisher), 'publish-maven-central.yml holds the Maven secrets');
  const resolve = publisher.steps.find(({ run }) => /node \.github\/release-run\.mjs/.test(run ?? ''));
  const taken = publisher.steps.find(({ uses }) => uses?.startsWith('actions/download-artifact@'));
  assert.equal(taken?.with?.name, 'prism-release', 'it takes the release job\'s hand-over');
  assert.equal(taken.with['run-id'], `\${{ steps.${resolve?.id}.outputs.run-id }}`, 'from the Release run release-run.mjs checked');
  const handover = publisher.steps.find(({ run }) => /jq -r \.mavenBundleSha256/.test(run ?? ''));
  assert.ok(handover?.id, 'it reads the digest from release.json');
  const releasing = publisher.steps.find(({ run }) =>
    /kotlin-release\.sh "\$RELEASE_TAG" "\$RUNNER_TEMP\/prism-release\/prism-compose-bundle"/.test(run ?? ''));
  assert.ok(releasing, 'it releases the downloaded bundle');
  assert.equal(releasing.env?.MAVEN_BUNDLE_SHA256, `\${{ steps.${handover.id}.outputs.sha256 }}`, 'the release step gets release.json\'s digest');
}

const mavenPublishing = readFileSync('.github/workflows/publish-maven-central.yml', 'utf8');

test('the release builds the Kotlin bundle without secrets, and the workflow that signs it takes that bundle as data', () => {
  checkKotlinRelease(release, mavenPublishing);
});

// The release or publish-maven-central.yml, edited so a bundle another job put in maven-bundle's
// place could be signed: each edit must fail the check.
const bundleDigest = '          MAVEN_BUNDLE_SHA256: ${{ needs.maven-bundle.outputs.sha256 }}\n';
const compareStep = '      - name: The Kotlin bundle is the one the maven-bundle job built\n        env:\n' + bundleDigest;
for (const [layout, edit] of Object.entries({
  'the bundle downloaded by name': () => [edited(release,
    '          artifact-ids: ${{ needs.maven-bundle.outputs.artifact-id }}\n          merge-multiple: true\n',
    '          name: prism-compose-bundle\n'), mavenPublishing],
  'no comparison of the bundle\'s digest': () => [edited(release, compareStep,
    compareStep.replace('MAVEN_BUNDLE_SHA256: ', 'OTHER: ')), mavenPublishing],
  'no digest among the bundle job\'s outputs': () => [edited(release, bundleOutputs, bundleOutputs.replace(/      sha256: .*\n/, '')), mavenPublishing],
  'no artifact id among the bundle job\'s outputs': () => [edited(release, bundleOutputs, bundleOutputs.replace(/      artifact-id: .*\n/, '')), mavenPublishing],
  'no digest given to the release step': () => [release,
    edited(mavenPublishing, '          MAVEN_BUNDLE_SHA256: ${{ steps.handover.outputs.sha256 }}\n', '')],
  'the bundle taken from another run': () => [release,
    edited(mavenPublishing, '          run-id: ${{ steps.release.outputs.run-id }}\n', '          run-id: ${{ inputs.run }}\n')],
  'another artifact than the release job\'s': () => [release,
    edited(mavenPublishing, '          name: prism-release\n', '          name: prism-compose-bundle\n')],
})) {
  test(`the check refuses a Kotlin release with ${layout}`, () => {
    assert.throws(() => checkKotlinRelease(...edit()), assert.AssertionError);
  });
}

// The release, edited so a job with the Maven secrets builds the library, in each way the
// guard must see; each edit is made in its test, so a release without the jobs fails there.
const signing = '      - name: Sign and upload the Kotlin library to Maven Central\n';
const bundleEnv = '      RELEASE_TAG: ${{ github.ref_name }}\n      GRADLE: "9.9.2"\n';
const bundleJob = '  maven-bundle:\n    needs: checks\n';
for (const [layout, edit] of Object.entries({
  'a Gradle run in maven-central': () =>
    edited(mavenPublishing, signing, `      - run: gradle -p targets/kotlin assemble\n${signing}`),
  'the bundle built in maven-central': () =>
    edited(mavenPublishing, signing, `      - run: .github/kotlin-release.sh --bundle 1.0.0 out\n${signing}`),
  'a JDK set up in maven-central': () =>
    edited(mavenPublishing, signing, `      - uses: actions/setup-java@d1374f8ac74474200d16ef8ecee22c7ae7a51880\n${signing}`),
  'a Maven secret in the bundle job': () =>
    edited(release, bundleEnv, `      KEY: \${{ secrets.MAVEN_SIGNING_KEY }}\n${bundleEnv}`),
  'all secrets in the bundle job\'s environment': () =>
    edited(release, bundleEnv, `      ALL: \${{ toJSON(secrets) }}\n${bundleEnv}`),
  'a secret named in capitals': () =>
    edited(release, bundleEnv, `      KEY: \${{ SECRETS.MAVEN_SIGNING_KEY }}\n${bundleEnv}`),
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

// Every artifact a job downloads from its own run is one a job it needs uploaded, by the id
// that job gives: a name could be another job's upload in the same run. From another run, a
// publish workflow takes only prism-release, of the Release run release-run.mjs checked.
function checkDownloads(file, yaml) {
  for (const job of jobs(yaml)) {
    for (const step of job.steps.filter(({ uses }) => uses?.startsWith('actions/download-artifact@'))) {
      const runId = step.with?.['run-id'];
      if (runId !== undefined) {
        const from = /^\$\{\{ steps\.([\w-]+)\.outputs\.run-id \}\}$/.exec(runId)?.[1];
        const resolve = job.steps.find(({ id }) => id === from);
        assert.ok(from && /^node \.github\/release-run\.mjs$/.test(resolve?.run ?? ''), `${file}: ${job.name} downloads from the Release run release-run.mjs checked`);
        assert.equal(step.with.name, 'prism-release', `${file}: ${job.name} takes the release job's prism-release`);
        assert.equal(step.with['artifact-ids'], undefined, `${file}: ${job.name} takes prism-release by its name`);
        continue;
      }
      const ids = step.with?.['artifact-ids'] ?? '';
      const from = /^\$\{\{ needs\.([\w-]+)\.outputs\.artifact-id \}\}$/.exec(ids)?.[1];
      assert.ok(from && job.needs.includes(from), `${file}: ${job.name} downloads ${ids || step.with?.name} by an id of a job it needs`);
      assert.equal(step.with.name, undefined, `${file}: ${job.name} downloads by id, not by name`);
    }
  }
}

test('every artifact a workflow downloads is taken by the id the job that uploaded it gives, or is the Release run\'s prism-release', () => {
  for (const file of workflows) checkDownloads(file, readFileSync(file, 'utf8'));
});

for (const [layout, file, from, to] of [
  ['prism-release taken from a run given by hand', '.github/workflows/publish-npm.yml',
    '          run-id: ${{ steps.release.outputs.run-id }}\n', '          run-id: ${{ inputs.run }}\n'],
  ['another artifact of the Release run', '.github/workflows/publish-npm.yml',
    '          name: prism-release\n', '          name: prism-npm-packages\n'],
  ['a release job\'s download by name', '.github/workflows/release.yml',
    '          artifact-ids: ${{ needs.npm-packages.outputs.artifact-id }}\n          merge-multiple: true\n', '          name: prism-npm-packages\n'],
]) {
  test(`the download check refuses ${layout}`, () => {
    const yaml = edited(readFileSync(file, 'utf8'), from, to);
    assert.throws(() => checkDownloads(file, yaml), assert.AssertionError);
  });
}

// prism-release is the release job's: no other job of Release uploads it, and the release job
// needs every other job, so none runs after it.
test('only the release job uploads prism-release, after every other job of the run', () => {
  const jobsOf = jobs(release);
  const uploaders = jobsOf.filter((job) => job.steps.some(({ uses, with: given }) =>
    uses?.startsWith('actions/upload-artifact@') && given?.name === 'prism-release'));
  assert.deepEqual(uploaders.map(({ name }) => name), ['release']);
  assert.deepEqual(uploaders[0].needs.toSorted(), jobsOf.map(({ name }) => name).filter((name) => name !== 'release').toSorted());
});

// The npm hand-over, as the Webflow and the Kotlin one: npm-packages, which can only read,
// packs the packages and gives the artifact's id and their digest; the release job downloads
// them by that id and compares the digest before it hands them on.
test('the release packs the npm packages in a job that can only read, and the release job takes them as data', () => {
  const jobsOf = jobs(release);
  const packer = jobsOf.find(({ name }) => name === 'npm-packages');
  assert.deepEqual(packer.permissions, { contents: 'read' });
  assert.ok(packer.steps.some(({ run }) => /node \.github\/release-prepare\.mjs/.test(run ?? '')), 'npm-packages packs the packages');
  const upload = packer.steps.find(({ uses }) => uses?.startsWith('actions/upload-artifact@'));
  assert.equal(packer.outputs['artifact-id'], `\${{ steps.${upload.id}.outputs.artifact-id }}`);
  const digest = packer.steps.find(({ id }) => `\${{ steps.${id}.outputs.sha256 }}` === packer.outputs.sha256);
  assert.match(digest?.run ?? '', /openssl dgst -sha256/);
  const steps = jobsOf.find(({ name }) => name === 'release').steps;
  const download = steps.findIndex(({ with: given }) => given?.['artifact-ids'] === '${{ needs.npm-packages.outputs.artifact-id }}');
  const compare = steps.findIndex(({ env, run }) =>
    env?.NPM_SHA256 === '${{ needs.npm-packages.outputs.sha256 }}' && /\$NPM_SHA256/.test(run ?? '') && /exit 1/.test(run ?? ''));
  const handsOn = steps.findIndex(({ with: given }) => given?.name === 'prism-release');
  assert.ok(download >= 0 && compare > download && handsOn > compare, 'the release job compares the packages\' digest before it hands them on');
  assert.equal(/echo "sha256=\$\((.*)\)" >> "\$GITHUB_OUTPUT"/.exec(digest.run)?.[1],
    /actual=\$\((.*)\)\n/.exec(steps[compare].run)?.[1], 'both jobs take the digest the same way');
});

// What Release does: it publishes nothing but the GitHub release. No job of it reads a secret
// or can get an OIDC token, the release job is the only one that can write, and it builds
// nothing.
const publishes = /release-publish\.mjs|swift-release\.sh|\bnpm publish\b|kotlin-release\.sh "\$RELEASE_TAG"|prism-swift/;
function checkRelease(yaml) {
  assert.doesNotMatch(yaml, /\bsecrets\b/i, 'Release reads no secret');
  const jobsOf = jobs(yaml);
  for (const job of jobsOf) {
    assert.notEqual(job.permissions['id-token'], 'write', `${job.name} gets no OIDC token`);
    for (const { run } of job.steps) assert.doesNotMatch(run ?? '', publishes, `${job.name} publishes nothing`);
  }
  const releaser = jobsOf.find(({ name }) => name === 'release');
  assert.deepEqual(releaser.permissions, { contents: 'write' });
  for (const { uses, run } of releaser.steps) {
    assert.doesNotMatch(uses ?? '', /^(actions\/setup-|erlef\/|gradle\/)/, 'the release job sets up no toolchain');
    // A build command where a command starts: at a line's start, or after ;, &&, || or (.
    assert.doesNotMatch(run ?? '', /(^|[;&|(]\s*)(npm|npx|mix|gradle|node)\s|kotlin-release\.sh --bundle/m, 'the release job runs no build');
  }
}

test('Release publishes nothing but the GitHub release, and its release job builds nothing', () => {
  checkRelease(release);
});

const attach = '      - name: Create GitHub release with design assets and bundles\n';
for (const [layout, from, to] of [
  ['npm run in the release job', attach, `      - run: npm ci\n        working-directory: targets/react\n${attach}`],
  ['a package built in the release job', attach, `      - run: |\n          cd targets/react && npm pack\n${attach}`],
  ['the npm packages published', attach, `      - run: node .github/release-publish.mjs\n${attach}`],
  ['the Swift package published', attach, `      - run: .github/swift-release.sh "$RELEASE_TAG" clone\n${attach}`],
  ['the Kotlin library signed', attach, `      - run: .github/kotlin-release.sh "$RELEASE_TAG" bundle\n${attach}`],
  ['a secret', '          GH_TOKEN: ${{ github.token }}\n', '          GH_TOKEN: ${{ secrets.PRISM_SWIFT_DEPLOY_KEY }}\n'],
  ['an OIDC token', '    permissions:\n      contents: write\n', '    permissions:\n      contents: write\n      id-token: write\n'],
]) {
  test(`the check refuses a Release with ${layout}`, () => {
    assert.throws(() => checkRelease(edited(release, from, to)), assert.AssertionError);
  });
}

// Each publish workflow: started by a Release run that succeeded for a version tag, or by
// hand with a version; never by `release: published`, which a release the workflow token
// made doesn't send. It has the permissions and secrets its target needs and no others, finds
// and checks the Release run with release-run.mjs before anything else, checks out that run's
// commit, and builds nothing.
const releaseRunIf = "github.event_name == 'workflow_dispatch' || (github.event.workflow_run.conclusion == 'success' && " +
  "github.event.workflow_run.event == 'push' && startsWith(github.event.workflow_run.head_branch, 'v'))";
const secretsOf = {
  '.github/workflows/publish-npm.yml': [],
  '.github/workflows/publish-swift.yml': ['PRISM_SWIFT_DEPLOY_KEY'],
  '.github/workflows/publish-maven-central.yml': [
    'MAVEN_CENTRAL_PASSWORD', 'MAVEN_CENTRAL_USERNAME', 'MAVEN_SIGNING_KEY', 'MAVEN_SIGNING_KEY_PASSWORD',
  ],
};

function checkPublisher(file, yaml) {
  const workflow = parse(yaml);
  assert.deepEqual(Object.keys(workflow.on).toSorted(), ['workflow_dispatch', 'workflow_run'], `${file}: its triggers`);
  assert.deepEqual(workflow.on.workflow_run, { workflows: ['Release'], types: ['completed'] }, `${file}: Release's runs`);
  assert.deepEqual(Object.keys(workflow.on.workflow_dispatch.inputs), ['version'], `${file}: by hand, with a version`);
  assert.equal(workflow.on.workflow_dispatch.inputs.version.required, true, `${file}: the version is required`);
  assert.deepEqual(workflow.permissions, {}, `${file}: no permissions but its job's`);
  assert.deepEqual(Object.keys(workflow.jobs).length, 1, `${file}: one job`);
  const [job] = jobs(yaml);
  assert.equal(job.raw.if.replace(/\s+/g, ' '), releaseRunIf, `${file}: only for a successful Release run of a version tag`);
  assert.deepEqual(job.permissions, publishers[file], `${file}: the permissions it needs`);
  const named = [...yaml.matchAll(/\bsecrets\.(\w+)/gi)].map(([, name]) => name).toSorted();
  assert.deepEqual(named, secretsOf[file], `${file}: the secrets it needs`);
  const resolve = job.steps.findIndex(({ run }) => run === 'node .github/release-run.mjs');
  assert.ok(resolve >= 0, `${file}: it checks the Release run`);
  assert.deepEqual(job.steps[resolve].env, {
    GH_TOKEN: '${{ github.token }}',
    RELEASE_RUN: '${{ toJSON(github.event.workflow_run) }}',
    VERSION: '${{ inputs.version }}',
  }, `${file}: of the event, or of the version given`);
  const id = job.steps[resolve].id;
  const checkout = job.steps.findIndex(({ uses, with: given }) =>
    uses?.startsWith('actions/checkout@') && given?.ref === `\${{ steps.${id}.outputs.commit }}`);
  assert.ok(checkout > resolve, `${file}: it checks out the Release run's commit`);
  job.steps.forEach(({ uses, run }, index) => {
    if (index >= resolve) return;
    assert.ok(uses?.startsWith('actions/checkout@'), `${file}: nothing but the checkout runs before the Release run is checked`);
  });
  for (const step of job.steps) {
    assert.equal(runsKotlinBuild(step), false, `${file}: no Kotlin build`);
    assert.doesNotMatch(step.run ?? '', /\bnpm (ci|install|pack)\b|\bmix\b|release-prepare/, `${file}: no build`);
  }
}

test('each target is published by a workflow of its own, from a successful Release run of a version tag', () => {
  for (const file of Object.keys(publishers)) checkPublisher(file, readFileSync(file, 'utf8'));
});

const npmPublishing = readFileSync('.github/workflows/publish-npm.yml', 'utf8');
for (const [layout, from, to] of [
  ['started by a published release', '  workflow_dispatch:\n', '  release:\n    types: [published]\n  workflow_dispatch:\n'],
  ['started by a failed Release run', "(github.event.workflow_run.conclusion == 'success' &&", '('],
  ['started by a Release run of a branch', "      github.event.workflow_run.event == 'push' &&\n      startsWith(github.event.workflow_run.head_branch, 'v'))", "      github.event.workflow_run.event == 'push')"],
  ['a secret it doesn\'t use', '          VERSION: ${{ inputs.version }}\n', '          VERSION: ${{ inputs.version }}\n          KEY: ${{ secrets.PRISM_SWIFT_DEPLOY_KEY }}\n'],
  ['write access to the repository', '      contents: read\n      actions: read\n', '      contents: write\n      actions: read\n'],
  ['another commit checked out', '          ref: ${{ steps.release.outputs.commit }}\n', '          ref: main\n'],
  ['no check of the Release run', '        run: node .github/release-run.mjs\n', '        run: echo "run-id=${{ github.event.workflow_run.id }}" >> "$GITHUB_OUTPUT"\n'],
  ['a rebuild of the packages', '      - name: Publish web then React', '      - run: npm ci\n        working-directory: targets/react\n      - name: Publish web then React'],
]) {
  test(`the check refuses a publish workflow ${layout}`, () => {
    const yaml = edited(npmPublishing, from, to);
    assert.throws(() => checkPublisher('.github/workflows/publish-npm.yml', yaml), assert.AssertionError);
  });
}

// Every Gradle setup uses the cache, and develop and main write it: a release's tag run can
// read only its own ref's cache and main's, the default branch's. With only develop writing,
// run 45257823269 (v0.6.0) downloaded everything from Maven Central and got an HTTP 429.
// A run writes the cache when its `cache-read-only` is false: `true` reads only, and an
// expression of the form `github.ref != 'A' && github.ref != 'B'` lets A and B write.
function cacheWriters(yaml) {
  const writers = [];
  for (const job of jobs(yaml)) {
    for (const step of job.steps) {
      if (step.uses?.startsWith('actions/setup-java@')) {
        assert.equal(step.with?.cache, undefined, `${job.name}: setup-gradle caches Gradle, not setup-java`);
      }
      if (!step.uses?.startsWith('gradle/actions/setup-gradle@')) continue;
      assert.notEqual(step.with?.['cache-disabled'], true, `${job.name}: the Gradle cache is on`);
      const readOnly = step.with?.['cache-read-only'];
      if (readOnly === true) continue;
      const refs = /^\$\{\{ github\.ref != '[^']+'(?: && github\.ref != '[^']+')* \}\}$/.test(readOnly ?? '')
        ? [...readOnly.matchAll(/'([^']+)'/g)].map(([, ref]) => ref)
        : ['unknown'];
      writers.push(...refs);
    }
  }
  return writers.sort();
}

test('develop and main write the Gradle cache, and every other run reads it', () => {
  assert.deepEqual(cacheWriters(readFileSync('.github/workflows/ci.yml', 'utf8')), ['refs/heads/develop', 'refs/heads/main']);
  assert.deepEqual(cacheWriters(release), []);
});
