// Third-party build trees stay out of jobs that can publish: the Webflow Designer
// Extension's npm packages (Webflow's CLI, ~700 of them) run only in a job that can
// read, and the release job takes its zip as data (ADR 0014).
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const workflows = ['.github/workflows/release.yml', '.github/workflows/ci.yml'];

// A permissions block's entries, from the lines indented below its key.
function permissions(lines, indent) {
  const at = lines.findIndex((line) => line === `${' '.repeat(indent)}permissions:`);
  if (at < 0) return null;
  const entries = [];
  for (const line of lines.slice(at + 1)) {
    const match = line.match(new RegExp(`^ {${indent + 2}}([\\w-]+): *(\\S+)`));
    if (!match) break;
    entries.push([match[1], match[2]]);
  }
  return Object.fromEntries(entries);
}

// The jobs of a workflow, each with its permissions (or the workflow's) and its steps,
// a step with the folder it runs in and its text.
function jobs(yaml) {
  const lines = yaml.split('\n');
  const top = permissions(lines.slice(0, lines.indexOf('jobs:')), 0) ?? {};
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

const canWrite = ({ permissions }) => Object.values(permissions).includes('write') || permissions === 'write-all';
const runsWebflowPackages = ({ folder, text }) =>
  /\bnpm\b|\bnpx\b|\bwebflow\b /.test(text.replace(/^ {8}(name|working-directory):.*$/gm, '')) &&
  (folder === 'targets/webflow' || /targets\/webflow/.test(text.replace(/^ {8}(name|path):.*$/gm, '')));

test('no job that can write runs the Webflow Designer Extension\'s npm packages', () => {
  for (const file of workflows) {
    for (const job of jobs(readFileSync(file, 'utf8'))) {
      if (!canWrite(job)) continue;
      const step = job.steps.find(runsWebflowPackages);
      assert.equal(step, undefined, `${file}: job ${job.name} can write and runs ${step?.text}`);
    }
  }
});

test('the release builds the Webflow bundle in a job that can only read, and the release job needs it', () => {
  const release = jobs(readFileSync('.github/workflows/release.yml', 'utf8'));
  const builders = release.filter((job) => job.steps.some(runsWebflowPackages));
  assert.deepEqual(builders.map(({ name, permissions }) => [name, permissions]), [['webflow', { contents: 'read' }]]);
  const publisher = release.find(({ permissions }) => permissions['id-token'] === 'write');
  assert.match(publisher.steps.map(({ text }) => text).join('\n'), /download-artifact[\s\S]*name: prism-tokens-webflow/);
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
