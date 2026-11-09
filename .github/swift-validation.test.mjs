import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fingerprint, findValidation, isSwiftInput } from './swift-validation.mjs';

const repository = 'example/prism';
const environment = {
  runnerImage: '20261101.1', osBuild: '25A1', xcode: 'Xcode 26.6\nBuild version 1',
  node: 'v24.1.0', arch: 'arm64', simulatorRuntime: 'iOS-26-6', simulatorBuild: '23A1', deviceType: 'iPhone-17',
};
const files = () => new Map([
  ['targets/swift/Package.swift', 'package'], ['targets/swift/Sources/Prism/Button.swift', 'button'],
  ['generator/test/fixtures/swift/components/Package.swift', 'fixture'],
  ['design/test/swiftui/Package.swift', 'checks'], ['design/test/swiftui/Tests/AnimationTests.swift', 'test'],
  ['.tool-versions', 'nodejs 24.1.0'], ['.github/workflows/ci.yml', 'ci'],
  ['.github/workflows/release.yml', 'release'], ['.github/swift-validation.mjs', 'selector'],
  ['.github/swift-validation.test.mjs', 'selector tests'],
]);
const expected = () => fingerprint(files(), environment);
const artifact = () => ({
  id: 50, name: `swift-validation-${expected().fingerprint}`, expired: false,
  workflow_run: { id: 100, repository_id: 1, head_repository_id: 1 },
});
const run = () => ({
  id: 100, run_attempt: 1, repository: { id: 1, full_name: repository }, head_repository: { id: 1 },
  event: 'push', path: '.github/workflows/ci.yml', status: 'completed', conclusion: 'success',
  html_url: 'https://github.com/example/prism/actions/runs/100',
});
const jobs = () => [{
  name: 'Swift package (iOS Simulator)', conclusion: 'success',
  steps: ['Build the packages', "Render Prism's components", 'Record successful Swift validation']
    .map(name => ({ name, conclusion: 'success' })),
}];
const record = () => ({ ...expected(), repository, runId: 100, runAttempt: 1 });
const api = overrides => ({
  artifacts: async () => ({ artifacts: [artifact()] }), run: async () => run(),
  jobs: async () => jobs(), record: async () => record(), ...overrides,
});
const select = overrides => findValidation(expected(), repository, api(overrides), 200);

test('documentation, web/React and release-version changes preserve the tested Swift identity', () => {
  const changed = files();
  for (const path of ['README.md', 'targets/swift/README.md', 'targets/swift/LICENSE',
    'targets/web/package.json', 'targets/react/package.json', 'design/mix.exs',
    'design/lib/tokens.ex', 'generator/lib/prism/generator/swift.ex']) changed.set(path, 'new bytes');
  // Generator/design jobs must still establish current Swift output before reuse.
  assert.deepEqual(fingerprint(changed, environment), expected());
});

test('every tested source, fixture, test, package and validation control invalidates reuse', () => {
  for (const path of files().keys()) {
    const changed = files(); changed.set(path, 'changed');
    assert.notEqual(fingerprint(changed, environment).fingerprint, expected().fingerprint, path);
  }
  for (const path of ['targets/swift/Resources/image.png',
    'generator/test/fixtures/swift/components/Sources/Kit/New.swift',
    'design/test/swiftui/Package.resolved']) {
    const changed = files(); changed.set(path, 'new');
    assert.notEqual(fingerprint(changed, environment).fingerprint, expected().fingerprint, path);
  }
  const removed = files(); removed.delete('targets/swift/Sources/Prism/Button.swift');
  assert.notEqual(fingerprint(removed, environment).fingerprint, expected().fingerprint);
  assert.equal(isSwiftInput('targets/swift/Sources/Prism/Resources/README.md'), true);
});

test('Xcode, simulator, OS, Node and runner image changes invalidate reuse', () => {
  for (const key of Object.keys(environment)) {
    assert.notEqual(fingerprint(files(), { ...environment, [key]: 'changed' }).fingerprint,
      expected().fingerprint, key);
  }
});

test('input order is irrelevant and missing packages or controls fail closed', () => {
  assert.deepEqual(fingerprint([...files()].reverse(), environment), expected());
  for (const path of ['targets/swift/Package.swift', '.github/workflows/ci.yml']) {
    const changed = files(); changed.delete(path);
    assert.throws(() => fingerprint(changed, environment), /Missing/);
  }
});

test('identical content reuses successful branch, internal PR and release workflow evidence', async () => {
  for (const [event, path, job] of [
    ['push', '.github/workflows/ci.yml', 'Swift package (iOS Simulator)'],
    ['pull_request', '.github/workflows/ci.yml', 'Swift package (iOS Simulator)'],
    ['push', '.github/workflows/release.yml', 'checks / Swift package (iOS Simulator)'],
  ]) {
    const result = await select({ run: async () => ({ ...run(), event, path }),
      jobs: async () => [{ ...jobs()[0], name: job }] });
    assert.equal(result.id, 100);
  }
});

test('absent, expired, corrupt, foreign or mismatched evidence requires the full suite', async () => {
  const cases = [
    { artifacts: async () => ({ artifacts: [] }) },
    { artifacts: async () => ({ artifacts: [{ ...artifact(), expired: true }] }) },
    { artifacts: async () => ({ artifacts: [{ ...artifact(), name: 'different' }] }) },
    { artifacts: async () => ({ artifacts: [{ ...artifact(), workflow_run: { id: 200 } }] }) },
    { artifacts: async () => ({ artifacts: [{ ...artifact(), workflow_run: { ...artifact().workflow_run, head_repository_id: 2 } }] }) },
    { record: async () => { throw new Error('digest mismatch or corrupt ZIP'); } },
    { record: async () => ({ ...record(), fingerprint: 'wrong' }) },
    { record: async () => ({ ...record(), inputs: [] }) },
    { record: async () => ({ ...record(), environment: {} }) },
    { record: async () => ({ ...record(), runId: 101 }) },
    { record: async () => ({ ...record(), runAttempt: 2 }) },
    { record: async () => ({ ...record(), schema: 2 }) },
    { run: async () => ({ ...run(), path: '.github/workflows/unrelated.yml' }) },
    { run: async () => ({ ...run(), head_repository: { id: 2 } }) },
    { run: async () => ({ ...run(), repository: { id: 1, full_name: 'other/repo' } }) },
    { run: async () => ({ ...run(), conclusion: 'failure' }) },
    { run: async () => ({ ...run(), status: 'in_progress' }) },
    { run: async () => ({ ...run(), event: 'workflow_dispatch' }) },
    { jobs: async () => [] },
    { jobs: async () => [{ ...jobs()[0], conclusion: 'skipped' }] },
    ...['Build the packages', "Render Prism's components", 'Record successful Swift validation']
      .map(name => ({ jobs: async () => [{ ...jobs()[0], steps: jobs()[0].steps
        .map(step => step.name === name ? { ...step, conclusion: 'skipped' } : step) }] })),
  ];
  for (const overrides of cases) assert.equal(await select(overrides), null);
});

test('an unavailable API fails safely to a full run', async () => {
  assert.equal(await select({ artifacts: async () => { throw new Error('HTTP 403'); } }), null);
});

test('pagination and invalid recent evidence do not hide an older valid run', async () => {
  const invalid = { ...artifact(), expired: true };
  const pages = [];
  assert.equal((await select({ artifacts: async (_name, page) => {
    pages.push(page); return { artifacts: page === 1 ? Array(100).fill(invalid) : [artifact()] };
  } })).id, 100);
  assert.deepEqual(pages, [1, 2]);
});
