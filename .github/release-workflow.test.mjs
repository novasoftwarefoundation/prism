// Third-party build trees stay out of jobs that can publish: the Webflow Designer
// Extension's npm packages (Webflow's CLI, ~700 of them) run only in a job that can
// read, and the release job takes its zip as data (ADR 0014).
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const workflows = ['.github/workflows/release.yml', '.github/workflows/ci.yml'];

// A `permissions:` key's value at this indent: an object of scopes, written as a block
// below the key or as a mapping on its line (`{ contents: write }`), or a level for
// every scope (`write-all`, `read-all`); undefined without the key. Any other form is
// "unknown", which counts as able to write.
function permissions(lines, indent) {
  const at = lines.findIndex((line) => line.startsWith(`${' '.repeat(indent)}permissions:`));
  if (at < 0) return undefined;
  const value = lines[at].slice(indent + 'permissions:'.length).replace(/\s+#.*$/, '').trim();
  if (/^(read|write)-all$/.test(value)) return value;
  if (/^\{.*\}$/.test(value)) {
    const entries = value.slice(1, -1).split(',').map((entry) => entry.trim()).filter(Boolean);
    const scopes = entries.map((entry) => entry.match(/^([\w-]+): *(read|write|none)$/));
    return scopes.every(Boolean) ? Object.fromEntries(scopes.map(([, scope, level]) => [scope, level])) : 'unknown';
  }
  if (value !== '') return 'unknown';
  const entries = [];
  for (const line of lines.slice(at + 1)) {
    const match = line.match(new RegExp(`^ {${indent + 2}}([\\w-]+): *(read|write|none)\\s*(#.*)?$`));
    if (!match) {
      if (new RegExp(`^ {${indent + 2}}`).test(line)) return 'unknown';
      break;
    }
    entries.push([match[1], match[2]]);
  }
  return Object.fromEntries(entries);
}

// The jobs of a workflow, each with its permissions (or the workflow's; without either,
// the repository's default, which may write) and its steps, a step with the folder it
// runs in and its text.
function jobs(yaml) {
  const lines = yaml.split('\n');
  const top = permissions(lines.slice(0, lines.indexOf('jobs:')), 0) ?? 'unknown';
  const starts = lines.flatMap((line, i) => (/^ {2}[\w-]+:$/.test(line) && i > lines.indexOf('jobs:') ? [i] : []));
  return starts.map((start, n) => {
    const job = lines.slice(start, starts[n + 1]);
    const folder = job.join('\n').match(/^ {4}defaults:\n {6}run:\n {8}working-directory: *(\S+)/m)?.[1] ?? '.';
    const stepStarts = job.flatMap((line, i) => (/^ {6}- /.test(line) ? [i] : []));
    const steps = stepStarts.map((at, k) => {
      const text = job.slice(at, stepStarts[k + 1]).join('\n');
      return { folder: text.match(/^ {8}working-directory: *(\S+)/m)?.[1] ?? folder, text };
    });
    return { name: job[0].trim().slice(0, -1), permissions: permissions(job, 4) ?? top, steps };
  });
}

const canWrite = ({ permissions }) =>
  typeof permissions === 'string' ? permissions !== 'read-all' : Object.values(permissions).includes('write');
const runsWebflowPackages = ({ folder, text }) =>
  /\bnpm\b|\bnpx\b|\bwebflow\b /.test(text.replace(/^ {8}(name|working-directory):.*$/gm, '')) &&
  (folder === 'targets/webflow' || /targets\/webflow/.test(text.replace(/^ {8}(name|path):.*$/gm, '')));

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
  assert.match(publisher.steps.map(({ text }) => text).join('\n'), /download-artifact[\s\S]*name: prism-tokens-webflow/);
});

test('the guard catches the release\'s webflow job given write access in any form', () => {
  const release = readFileSync('.github/workflows/release.yml', 'utf8');
  const block = '    permissions:\n      contents: read\n    defaults:';
  assert.equal(release.split(block).length, 2, "the webflow job's permissions block");
  for (const written of [
    '    permissions: write-all',
    '    permissions: { contents: write, id-token: write }',
    '    permissions:\n      contents: write',
    '    permissions: ${{ fromJSON(inputs.permissions) }}',
  ]) {
    const yaml = release.replace(block, `${written}\n    defaults:`);
    assert.deepEqual(writersRunningWebflow(yaml), ['webflow'], written);
  }
  // Without its own block, the job has the workflow's; without that, the default's.
  const inherits = release.replace(block, '    defaults:');
  assert.deepEqual(writersRunningWebflow(inherits), [], 'the workflow reads');
  const noTop = inherits.replace(/^permissions:\n {2}contents: read\n/m, '');
  assert.notEqual(noTop, inherits);
  assert.deepEqual(writersRunningWebflow(noTop), ['webflow'], 'no top-level block');
});

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
        working-directory: targets/webflow
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
  // No permissions anywhere: the repository's default token, which may write.
  assert.equal(canWrite(jobs('jobs:\n  build:\n    steps:\n      - run: npm ci\n')[0]), true);
});
