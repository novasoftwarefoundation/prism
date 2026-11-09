// Third-party build trees stay out of jobs that can publish: the Webflow Designer
// Extension's npm packages (Webflow's CLI, ~700 of them) run only in a job that can
// read, and the release job takes its zip as data (ADR 0014). The workflows are read
// with a YAML parser, and what the guard can't classify counts against it.
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
    return { name, permissions: permissions(job.permissions) ?? top, steps };
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
