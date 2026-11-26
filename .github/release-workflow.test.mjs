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
const workflows = ['.github/workflows/release.yml', '.github/workflows/ci.yml', ...Object.keys(publishers), '.github/workflows/compare.yml'];

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
  const noTop = edited(inherits, '\npermissions:\n  contents: read\n\n', '\n');
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
// that digest into release.json, which it attaches to the GitHub release.
// publish-maven-central.yml, which holds the Maven secrets, takes the bundle from the Release
// run's prism-release artifact, and its release step gets the digest from release.json on the
// release, which the script checks before it signs.
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
  checkAnchorWritten(releaser);

  const [publisher] = jobs(publishing);
  assert.ok(readsSecrets(publisher), 'publish-maven-central.yml holds the Maven secrets');
  const resolve = publisher.steps.find(({ run }) => /node \.github\/release-run\.mjs/.test(run ?? ''));
  const taken = publisher.steps.find(({ uses }) => uses?.startsWith('actions/download-artifact@'));
  assert.equal(taken?.with?.name, 'prism-release', 'it takes the release job\'s hand-over');
  assert.equal(taken.with['run-id'], `\${{ steps.${resolve?.id}.outputs.run-id }}`, 'from the Release run release-run.mjs checked');
  const handover = checkMavenHandover(publisher, resolve);
  const releasing = publisher.steps.find(({ run }) =>
    /kotlin-release\.sh "\$RELEASE_TAG" "\$RUNNER_TEMP\/prism-release\/prism-compose-bundle"/.test(run ?? ''));
  assert.ok(releasing, 'it releases the downloaded bundle');
  assert.equal(releasing.env?.MAVEN_BUNDLE_SHA256, `\${{ steps.${handover.id}.outputs.sha256 }}`, 'the release step gets release.json\'s digest');
}

const mavenPublishing = readFileSync('.github/workflows/publish-maven-central.yml', 'utf8');
const npmPublishing = readFileSync('.github/workflows/publish-npm.yml', 'utf8');

// The hand-over's digests are anchored outside the artifact: the release job, which alone can
// write the GitHub release, writes release.json beside prism-release, never into it, after it
// checked the bundle and the packages, and attaches it to the release. The publish workflows
// fetch it from the release and check the artifact against it, never against values inside
// the artifact, which a job of the Release run that ran third-party code could replace whole.
const anchorDownload = 'gh release download "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" --pattern release.json --dir "$RUNNER_TEMP/release-assets"';
const anchorFile = '"$RUNNER_TEMP/release-assets/release.json"';

function checkAnchorWritten(releaser) {
  const steps = releaser.steps;
  const written = steps.findIndex(({ run }) => /> "\$RUNNER_TEMP\/release\.json"/.test(run ?? ''));
  assert.ok(written >= 0, 'the release job writes release.json beside prism-release');
  assert.equal(steps[written].env?.MAVEN_BUNDLE_SHA256, '${{ needs.maven-bundle.outputs.sha256 }}', 'release.json holds the bundle job\'s digest');
  assert.match(steps[written].run, /cd "\$RUNNER_TEMP\/prism-release\/npm-packages"/, 'and the sha256 of each npm file');
  const checked = steps.findIndex(({ env }) => env?.NPM_SHA256 === '${{ needs.npm-packages.outputs.sha256 }}');
  assert.ok(checked >= 0 && written > checked, 'after the packages are checked');
  const attached = steps.findIndex(({ run }) => /gh release upload [^\n]*(\n[^\n]*)*"\$RUNNER_TEMP\/release\.json"/.test(run ?? ''));
  assert.ok(attached > written, 'the release job attaches release.json to the GitHub release');
  for (const { run } of steps) {
    assert.doesNotMatch(run ?? '', /prism-release\/release\.json|> *"\$RUNNER_TEMP\/prism-release/, 'nothing is written into prism-release');
  }
}

// The step that gives the bundle's digest: it fetches release.json from the release, checks
// its tag and commit against the Release run release-run.mjs checked, and only then reads the
// digest, all from that file.
function checkMavenHandover(publisher, resolve) {
  const handover = publisher.steps.find(({ run }) => /mavenBundleSha256/.test(run ?? ''));
  assert.ok(handover?.id, 'it reads the bundle\'s digest in a step of its own');
  const lines = handover.run.trim().split('\n');
  assert.deepEqual(lines, [
    anchorDownload,
    `release=${anchorFile}`,
    'test "$(jq -r .tag "$release")" = "$RELEASE_TAG"',
    'test "$(jq -r .commit "$release")" = "$COMMIT"',
    'echo "sha256=$(jq -r .mavenBundleSha256 "$release")" >> "$GITHUB_OUTPUT"',
  ], 'from release.json on the release, for the checked tag and commit, before the digest');
  assert.equal(handover.env?.RELEASE_TAG, `\${{ steps.${resolve.id}.outputs.tag }}`, 'the checked tag');
  assert.equal(handover.env?.COMMIT, `\${{ steps.${resolve.id}.outputs.commit }}`, 'the checked commit');
  return handover;
}

// Publish npm: release.json fetched from the release, and handed to release-publish.mjs with
// the checked tag and commit; release-publish.mjs checks the folder against it.
function checkNpmHandover(yaml) {
  const [job] = jobs(yaml);
  const resolve = job.steps.find(({ run }) => run === 'node .github/release-run.mjs');
  const fetched = job.steps.findIndex(({ run }) => run === anchorDownload);
  assert.ok(fetched >= 0, 'Publish npm fetches release.json from the release');
  assert.equal(job.steps[fetched].env?.RELEASE_TAG, `\${{ steps.${resolve.id}.outputs.tag }}`, 'of the checked tag');
  const publishing = job.steps.findIndex(({ run }) => run === 'node .github/release-publish.mjs');
  assert.ok(publishing > fetched, 'before it publishes');
  assert.deepEqual(job.steps[publishing].env, {
    RELEASE_TAG: `\${{ steps.${resolve.id}.outputs.tag }}`,
    RELEASE_COMMIT: `\${{ steps.${resolve.id}.outputs.commit }}`,
    RELEASE_JSON: '${{ runner.temp }}/release-assets/release.json',
    NPM_PACKAGES: '${{ runner.temp }}/prism-release/npm-packages',
  }, 'release-publish.mjs checks the artifact against the release\'s release.json');
}

test('the publish workflows check prism-release against release.json on the GitHub release, never against the artifact', () => {
  checkNpmHandover(npmPublishing);
  const [publisher] = jobs(mavenPublishing);
  checkMavenHandover(publisher, publisher.steps.find(({ run }) => run === 'node .github/release-run.mjs'));
  checkAnchorWritten(jobs(release).find(({ name }) => name === 'release'));
});

const handoverStep = '          release="$RUNNER_TEMP/release-assets/release.json"\n';
for (const [layout, edit, check] of [
  ['the bundle\'s digest read from the artifact', () => edited(mavenPublishing, handoverStep,
    '          release="$RUNNER_TEMP/prism-release/release.json"\n'), 'maven'],
  ['no tag check of release.json', () => edited(mavenPublishing,
    '          test "$(jq -r .tag "$release")" = "$RELEASE_TAG"\n', ''), 'maven'],
  ['no commit check of release.json', () => edited(mavenPublishing,
    '          test "$(jq -r .commit "$release")" = "$COMMIT"\n', ''), 'maven'],
  ['the digest read before the checks', () => edited(mavenPublishing,
    '          test "$(jq -r .tag "$release")" = "$RELEASE_TAG"\n',
    '          echo "sha256=$(jq -r .mavenBundleSha256 "$release")" >> "$GITHUB_OUTPUT"\n          test "$(jq -r .tag "$release")" = "$RELEASE_TAG"\n'), 'maven'],
  ['release.json not fetched from the release', () => edited(mavenPublishing, `          ${anchorDownload}\n`, ''), 'maven'],
  ['the npm digests read from the artifact', () => edited(npmPublishing,
    '          RELEASE_JSON: ${{ runner.temp }}/release-assets/release.json\n',
    '          RELEASE_JSON: ${{ runner.temp }}/prism-release/release.json\n'), 'npm'],
  ['the npm digests read from the artifact\'s manifest', () => edited(npmPublishing,
    '          RELEASE_JSON: ${{ runner.temp }}/release-assets/release.json\n',
    '          RELEASE_JSON: ${{ runner.temp }}/prism-release/npm-packages/prism-release.json\n'), 'npm'],
  ['no commit for the npm check', () => edited(npmPublishing,
    '          RELEASE_COMMIT: ${{ steps.release.outputs.commit }}\n', ''), 'npm'],
  ['release.json not fetched for npm', () => edited(npmPublishing, `        run: ${anchorDownload}\n`, '        run: "true"\n'), 'npm'],
  ['release.json written into prism-release', () => edited(release,
    '> "$RUNNER_TEMP/release.json"', '> "$RUNNER_TEMP/prism-release/release.json"'), 'release'],
  ['release.json not attached to the release', () => edited(release,
    ' "$RUNNER_TEMP/release.json" --clobber', ' --clobber'), 'release'],
]) {
  test(`the hand-over check refuses ${layout}`, () => {
    const yaml = edit();
    assert.throws(() => {
      if (check === 'npm') return checkNpmHandover(yaml);
      if (check === 'release') return checkAnchorWritten(jobs(yaml).find(({ name }) => name === 'release'));
      const [publisher] = jobs(yaml);
      return checkMavenHandover(publisher, publisher.steps.find(({ run }) => run === 'node .github/release-run.mjs'));
    }, assert.AssertionError);
  });
}

// Every run of Release and of each publish workflow waits its turn in its group: with the
// default queue (`single`), a run joining the group cancels the one already waiting, and that
// version goes unpublished without a failure.
const queued = {
  '.github/workflows/release.yml': 'prism-release',
  '.github/workflows/publish-npm.yml': 'prism-publish-npm',
  '.github/workflows/publish-swift.yml': 'prism-publish-swift',
  '.github/workflows/publish-maven-central.yml': 'prism-publish-maven-central',
  '.github/workflows/compare.yml': 'prism-compare',
};
const checkQueue = (file, yaml) =>
  assert.deepEqual(parse(yaml).concurrency, { group: queued[file], 'cancel-in-progress': false, queue: 'max' }, file);

test('no run of Release or a publish workflow is cancelled by a later one: their groups queue every run', () => {
  for (const file of Object.keys(queued)) checkQueue(file, readFileSync(file, 'utf8'));
});

for (const file of Object.keys(queued)) {
  test(`the queue check refuses ${file} with the default queue`, () => {
    const yaml = edited(readFileSync(file, 'utf8'), '  queue: max\n', '');
    assert.throws(() => checkQueue(file, yaml), assert.AssertionError);
  });
}

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

// The compare (compare.yml), as the other hand-overs, and apart from the release: it starts
// after a successful Release run, which never waits on it. Each compare job, which can only
// read, makes its target's images with compare.sh at the tag's commit and gives the artifact's
// id and their digest; the attach job, the only one that can write, builds nothing, downloads
// them by that id and compares each digest before it attaches the images.
const compareWorkflow = readFileSync('.github/workflows/compare.yml', 'utf8');
// The attach job's digest check, exactly: any other line could change what the upload step
// runs ($GITHUB_PATH, $GITHUB_ENV) or read the token by another spelling.
const compareDigestRun = [
  "for target in android ios web; do",
  "  expected=$(printenv \"$(echo \"$target\" | tr a-z A-Z)_SHA256\" || true)",
  "  actual=$(cd \"$RUNNER_TEMP/compare/$target\" && LC_ALL=C openssl dgst -sha256 compare-*.png | openssl dgst -sha256 | sed 's/.*= //')",
  "  if [ -z \"$expected\" ] || [ \"$actual\" != \"$expected\" ]; then",
  "    echo \"::error::The $target compare images' digest is $actual, not the compare-$target job's ${expected:-(none)}\"",
  "    exit 1",
  "  fi",
  "done",
].join('\n') + '\n';
const downloadArtifact = 'actions/download-artifact@9000827ccba6bdab643e8b6fd33ac0654aef8333';
function checkCompare(yaml) {
  assert.doesNotMatch(yaml, /\bsecrets\b/i, 'Compare reads no secret');
  const workflow = parse(yaml);
  assert.deepEqual(workflow.on.workflow_run, { workflows: ['Release'], types: ['completed'] }, 'it starts after Release');
  const jobsOf = jobs(yaml);
  assert.deepEqual(jobsOf.filter(canWrite).map(({ name }) => name), ['attach'], 'only the attach job can write');
  const tag = jobsOf.find(({ name }) => name === 'tag');
  assert.ok(tag.steps.some(({ run }) => run === 'node .github/release-run.mjs'), 'the tag job checks the Release run');
  const attach = jobsOf.find(({ name }) => name === 'attach');
  for (const { uses, run } of attach.steps) {
    assert.doesNotMatch(uses ?? '', /^(actions\/checkout|actions\/setup-|erlef\/|gradle\/)/, 'the attach job checks out and sets up nothing');
    assert.doesNotMatch(run ?? '', /(^|[;&|(]\s*)(npm|npx|mix|gradle|node)\s|compare\.sh/m, 'the attach job runs no build');
  }
  // The one other job than Release's release job that can write a release, held to exactly
  // its permissions, runner, needs and steps: the three downloads by id at the pinned
  // download-artifact commit, the digest check's command and the upload's command, each step
  // with exactly its keys (no if, shell or continue-on-error) and environment, and only the
  // upload has the token. So an edit that changes what it runs fails the check, and with it
  // one that would write release.json, which the publish workflows trust.
  assert.equal(workflow.env, undefined, 'the workflow has no environment every job gets');
  assert.equal(workflow.defaults, undefined, 'the workflow has no defaults every job gets');
  assert.deepEqual(Object.keys(attach.raw).toSorted(), ['needs', 'permissions', 'runs-on', 'steps', 'timeout-minutes'],
    'the attach job has no environment, defaults, container or services');
  assert.deepEqual(attach.raw.permissions, { contents: 'write' }, 'the attach job can write contents and nothing else');
  assert.equal(attach.raw['runs-on'], 'ubuntu-latest', 'the attach job runs on GitHub\'s runner');
  assert.deepEqual(attach.needs, ['tag', 'compare-android', 'compare-ios', 'compare-web']);
  const steps = attach.raw.steps;
  assert.deepEqual(steps.map((step) => Object.keys(step).toSorted()),
    [['uses', 'with'], ['uses', 'with'], ['uses', 'with'], ['env', 'name', 'run'], ['env', 'name', 'run']],
    'the attach job\'s steps: three downloads, the digest check and the upload');
  for (const [index, target] of ['android', 'ios', 'web'].entries()) {
    assert.equal(steps[index].uses, downloadArtifact);
    assert.deepEqual(steps[index].with, {
      'artifact-ids': `\${{ needs.compare-${target}.outputs.artifact-id }}`,
      'merge-multiple': true,
      path: `\${{ runner.temp }}/compare/${target}`,
    });
  }
  const [compare, attaches] = [3, 4];
  assert.equal(steps[compare].run, compareDigestRun, 'the attach job\'s digest check is exactly that');
  assert.deepEqual(steps[compare].env, Object.fromEntries(['android', 'ios', 'web'].map((target) =>
    [`${target.toUpperCase()}_SHA256`, `\${{ needs.compare-${target}.outputs.sha256 }}`])));
  assert.deepEqual(steps[attaches].env, { GH_TOKEN: '${{ github.token }}', RELEASE_TAG: '${{ needs.tag.outputs.tag }}' },
    'it attaches them to the checked tag\'s release');
  assert.equal(steps[attaches].run,
    'gh release upload "$RELEASE_TAG" "$RUNNER_TEMP"/compare/*/compare-*.png --clobber --repo "$GITHUB_REPOSITORY"',
    'the attach job uploads only the compare images');
  for (const step of steps.slice(0, attaches)) {
    assert.doesNotMatch(JSON.stringify(step), /github\.token|GITHUB_TOKEN|secrets\./i, 'only the upload step has the token');
  }
  assert.match(steps[compare].run, /exit 1/);
  for (const target of ['android', 'ios', 'web']) {
    const maker = jobsOf.find(({ name }) => name === `compare-${target}`);
    assert.deepEqual(maker?.permissions, { contents: 'read' }, `compare-${target} can only read`);
    assert.ok(maker.needs.includes('tag') && attach.needs.includes(`compare-${target}`));
    const checkout = maker.steps.find(({ uses }) => uses?.startsWith('actions/checkout@'));
    assert.equal(checkout?.with?.ref, '${{ needs.tag.outputs.commit }}', `compare-${target} makes the tag's commit's images`);
    assert.ok(maker.steps.some(({ run }) => run === `design/test/compare/compare.sh --only ${target} "$RUNNER_TEMP/compare"`));
    const upload = maker.steps.find(({ uses }) => uses?.startsWith('actions/upload-artifact@'));
    assert.equal(maker.outputs['artifact-id'], `\${{ steps.${upload.id}.outputs.artifact-id }}`);
    const digest = maker.steps.find(({ id }) => `\${{ steps.${id}.outputs.sha256 }}` === maker.outputs.sha256);
    assert.equal(/echo "sha256=\$\((.*)\)" >> "\$GITHUB_OUTPUT"/.exec(digest?.run ?? '')?.[1],
      /actual=\$\(cd "\$RUNNER_TEMP\/compare\/\$target" && (.*)\)\n/.exec(steps[compare].run)?.[1],
      `compare-${target} and the attach job take the digest the same way`);
    const download = steps.findIndex(({ with: given }) => given?.['artifact-ids'] === `\${{ needs.compare-${target}.outputs.artifact-id }}`);
    assert.ok(download >= 0 && download < compare, `the attach job downloads compare-${target}'s images by its id first`);
    assert.equal(steps[compare].env?.[`${target.toUpperCase()}_SHA256`], `\${{ needs.compare-${target}.outputs.sha256 }}`);
  }
}

test('the compare makes its images in jobs that can only read, and the attach job takes them as data', () => {
  checkCompare(compareWorkflow);
});

test('Release and the publish workflows never wait on the compare', () => {
  for (const file of ['.github/workflows/release.yml', ...Object.keys(publishers)]) {
    const yaml = readFileSync(file, 'utf8');
    assert.ok(![].concat(parse(yaml).on?.workflow_run?.workflows ?? []).includes('Compare'), `${file} starts after Compare`);
    for (const job of jobs(yaml)) {
      assert.ok(!job.needs.some((name) => name.startsWith('compare-')), `${file}: ${job.name} needs a compare job`);
      for (const { run } of job.steps) assert.doesNotMatch(run ?? '', /compare\.(sh|yml)/, `${file}: ${job.name} runs the compare`);
    }
  }
});

for (const [layout, from, to] of [
  ['the web images\' digest not compared', '          WEB_SHA256: ${{ needs.compare-web.outputs.sha256 }}\n', ''],
  ['no digest among the iOS job\'s outputs',
    '      sha256: ${{ steps.digest.outputs.sha256 }}\n    steps:\n      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1\n        with:\n          ref: ${{ needs.tag.outputs.commit }}\n          persist-credentials: false\n      # CI\'s Xcode',
    '    steps:\n      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1\n        with:\n          ref: ${{ needs.tag.outputs.commit }}\n          persist-credentials: false\n      # CI\'s Xcode'],
  ['the web images made from the default branch', '          ref: ${{ needs.tag.outputs.commit }}\n          persist-credentials: false\n      - uses: actions/setup-node', '          persist-credentials: false\n      - uses: actions/setup-node'],
  ['release.json uploaded with the images',
    '"$RUNNER_TEMP"/compare/*/compare-*.png --clobber', '"$RUNNER_TEMP"/compare/*/compare-*.png "$RUNNER_TEMP"/compare/*/release.json --clobber'],
  ['another upload after the images',
    ' --clobber --repo "$GITHUB_REPOSITORY"\n',
    ' --clobber --repo "$GITHUB_REPOSITORY"\n      - run: gh release upload "$RELEASE_TAG" "$RUNNER_TEMP/compare/web/release.json" --clobber\n        env:\n          GH_TOKEN: ${{ github.token }}\n          RELEASE_TAG: ${{ needs.tag.outputs.tag }}\n'],
  ['a github-script step that uploads release.json',
    ' --clobber --repo "$GITHUB_REPOSITORY"\n',
    ' --clobber --repo "$GITHUB_REPOSITORY"\n      - uses: actions/github-script@60a0d83039c74a4aee543508d2ffcb1c3799cdea # v7.0.1\n        with:\n          script: |\n            await github.rest.repos.uploadReleaseAsset({owner: context.repo.owner, repo: context.repo.repo, release_id: 1, name: \'release.json\', data: require(\'fs\').readFileSync(process.env.RUNNER_TEMP + \'/compare/web/release.json\')})\n'],
  ['a curl step that uploads release.json with the token',
    ' --clobber --repo "$GITHUB_REPOSITORY"\n',
    ' --clobber --repo "$GITHUB_REPOSITORY"\n      - name: More\n        env:\n          GH_TOKEN: ${{ github.token }}\n        run: |\n          curl -sf -X POST -H "Authorization: Bearer $GH_TOKEN" --data-binary @"$RUNNER_TEMP/compare/web/release.json" "https://uploads.github.com/repos/$GITHUB_REPOSITORY/releases/1/assets?name=release.json"\n'],
  ['the token given to the digest step',
    '          WEB_SHA256: ${{ needs.compare-web.outputs.sha256 }}\n',
    '          WEB_SHA256: ${{ needs.compare-web.outputs.sha256 }}\n          GH_TOKEN: ${{ github.token }}\n'],
  ['the token in the attach job\'s environment',
    '    permissions:\n      contents: write\n',
    '    permissions:\n      contents: write\n    env:\n      GH_TOKEN: ${{ github.token }}\n'],
  ['the digest check skipped',
    '      - name: The compare images are the ones the compare jobs made\n',
    '      - name: The compare images are the ones the compare jobs made\n        if: false\n'],
  ['a fake gh put first on the PATH by the digest step',
    '            fi\n          done\n',
    '            fi\n          done\n          mkdir -p "$RUNNER_TEMP/bin"\n          printf \'#!/bin/sh\\nexec /usr/bin/gh release upload "$RELEASE_TAG" "$RUNNER_TEMP"/compare/web/release.json --clobber --repo "$GITHUB_REPOSITORY"\\n\' > "$RUNNER_TEMP/bin/gh"\n          chmod +x "$RUNNER_TEMP/bin/gh"\n          echo "$RUNNER_TEMP/bin" >> "$GITHUB_PATH"\n'],
  ['a BASH_ENV set by the digest step',
    '            fi\n          done\n',
    '            fi\n          done\n          echo \'gh release upload "$RELEASE_TAG" "$RUNNER_TEMP"/compare/web/release.json --clobber --repo "$GITHUB_REPOSITORY"\' > "$RUNNER_TEMP/x.sh"\n          echo "BASH_ENV=$RUNNER_TEMP/x.sh" >> "$GITHUB_ENV"\n'],
  ['the token read in the digest step by another spelling',
    '        run: |\n          for target in android ios web; do\n',
    '        run: |\n          T="${{ github[\'token\'] }}"; curl -sf -X POST -H "Authorization: Bearer $T" --data-binary @"$RUNNER_TEMP/compare/web/release.json" "https://uploads.github.com/repos/$GITHUB_REPOSITORY/releases/1/assets?name=release.json"\n          for target in android ios web; do\n'],
  ['the attach job given write-all',
    '    permissions:\n      contents: write\n',
    '    permissions: write-all\n'],
  ['the attach job given id-token too',
    '    permissions:\n      contents: write\n',
    '    permissions:\n      contents: write\n      id-token: write\n'],
  ['the attach job on a self-hosted runner',
    '    runs-on: ubuntu-latest\n    timeout-minutes: 10\n',
    '    runs-on: self-hosted\n    timeout-minutes: 10\n'],
  ['a download at another commit',
    '      - uses: actions/download-artifact@9000827ccba6bdab643e8b6fd33ac0654aef8333 # v8.0.2\n        with:\n          artifact-ids: ${{ needs.compare-web.outputs.artifact-id }}\n',
    '      - uses: actions/download-artifact@1111111111111111111111111111111111111111\n        with:\n          artifact-ids: ${{ needs.compare-web.outputs.artifact-id }}\n'],
  ['a secret given to compare-web',
    '      - name: The compare on the web\n',
    '      - name: The compare on the web\n        env:\n          KEY: ${{ secrets.MAVEN_SIGNING_KEY }}\n'],
  ['a compare job that can write', '  compare-web:\n    needs: tag\n    runs-on: ubuntu-latest\n    timeout-minutes: 15\n    permissions:\n      contents: read\n', '  compare-web:\n    needs: tag\n    runs-on: ubuntu-latest\n    timeout-minutes: 15\n    permissions:\n      contents: write\n'],
]) {
  test(`the check refuses a compare with ${layout}`, () => {
    assert.throws(() => checkCompare(edited(compareWorkflow, from, to)), assert.AssertionError);
  });
}

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
