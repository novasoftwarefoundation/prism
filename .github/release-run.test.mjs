import assert from 'node:assert/strict';
import { test } from 'node:test';
import { commitOf, dispatchRun, releaseRun, tagOf } from './release-run.mjs';

const repository = 'novasoftwarefoundation/prism';
const commit = 'f652d710aabcd806e1bc1e0f9d9aa362ff27a32e';
const run = {
  id: 45257823269,
  path: '.github/workflows/release.yml',
  event: 'push',
  head_branch: 'v0.6.0',
  head_sha: commit,
  conclusion: 'success',
  repository: { full_name: repository },
  head_repository: { full_name: repository },
};
const check = (edit = {}, tag = 'v0.6.0', tagCommit = commit) =>
  releaseRun({ ...run, ...edit }, { repository, tag, tagCommit });

test('a successful Release run of the tag, at its commit, is the one to publish from', () => {
  assert.deepEqual(check(), { tag: 'v0.6.0', version: '0.6.0', commit, runId: 45257823269 });
  assert.deepEqual(check({ head_branch: 'v1.0.0-rc.2' }, 'v1.0.0-rc.2').version, '1.0.0-rc.2');
});

for (const [layout, edit, tag, tagCommit] of [
  ['that failed', { conclusion: 'failure' }],
  ['that was cancelled', { conclusion: 'cancelled' }],
  ['still running', { conclusion: null }],
  ['of another workflow', { path: '.github/workflows/ci.yml' }],
  ['of a workflow named Release in another file', { path: '.github/workflows/release-copy.yml' }],
  ['started by a pull request', { event: 'pull_request' }],
  ['started by hand', { event: 'workflow_dispatch' }],
  ['of a branch named like a tag', { head_branch: 'v0.6.0-fix' }, 'v0.6.0'],
  ['of another tag', { head_branch: 'v0.5.0' }],
  ['of a fork\'s commit', { head_repository: { full_name: 'someone/prism' } }],
  ['of another repository', { repository: { full_name: 'someone/prism' } }],
  ['at another commit than the tag\'s', {}, 'v0.6.0', '0'.repeat(40)],
  ['for a tag that is no version', { head_branch: 'v0.6' }, 'v0.6'],
  ['without an id', { id: undefined }],
]) {
  test(`a Release run ${layout} is refused`, () => {
    assert.throws(() => check(edit, tag, tagCommit), assert.AssertionError);
  });
}

test('the version typed in by hand is a tag with or without its v', () => {
  assert.equal(tagOf('0.6.0'), 'v0.6.0');
  assert.equal(tagOf('v0.6.0'), 'v0.6.0');
});

// A fake of the REST API: each path's JSON, and the paths asked for.
function fakeApi(responses) {
  const asked = [];
  const api = (path) => {
    asked.push(path);
    assert.ok(path in responses, `no fake for ${path}`);
    return structuredClone(responses[path]);
  };
  return { api, asked };
}

const tagObject = 'bb1a5b5' + '0'.repeat(33);
const runs = (list) => ({
  [`repos/${repository}/actions/workflows/release.yml/runs?event=push&branch=v0.6.0&status=success&per_page=100`]: { workflow_runs: list },
});
const annotated = {
  [`repos/${repository}/git/ref/tags/v0.6.0`]: { object: { type: 'tag', sha: tagObject } },
  [`repos/${repository}/git/tags/${tagObject}`]: { object: { type: 'commit', sha: commit } },
};

test('an annotated tag is peeled to its commit, and a lightweight tag is its commit', () => {
  assert.equal(commitOf(fakeApi(annotated).api, repository, 'v0.6.0'), commit);
  const lightweight = { [`repos/${repository}/git/ref/tags/v0.6.0`]: { object: { type: 'commit', sha: commit } } };
  assert.equal(commitOf(fakeApi(lightweight).api, repository, 'v0.6.0'), commit);
});

test('a tag that points at no commit is refused', () => {
  const tree = { [`repos/${repository}/git/ref/tags/v0.6.0`]: { object: { type: 'tree', sha: commit } } };
  assert.throws(() => commitOf(fakeApi(tree).api, repository, 'v0.6.0'), assert.AssertionError);
});

test('by hand, the newest successful Release run at the tag\'s commit is the one, and runs at another commit are skipped', () => {
  const other = { ...run, id: 3, head_sha: '1'.repeat(40) };
  const newest = { ...run, id: 2 };
  const older = { ...run, id: 1 };
  const { api, asked } = fakeApi({ ...annotated, ...runs([other, newest, older]) });
  assert.deepEqual(dispatchRun(api, repository, '0.6.0'), { run: newest, tag: 'v0.6.0' });
  assert.deepEqual(dispatchRun(api, repository, 'v0.6.0').run.id, 2);
  assert.ok(asked.some((path) => path.includes('event=push') && path.includes('status=success')), 'only successful push runs');
});

test('by hand, a version without a successful Release run at its tag\'s commit is refused', () => {
  const { api } = fakeApi({ ...annotated, ...runs([{ ...run, head_sha: '1'.repeat(40) }]) });
  assert.throws(() => dispatchRun(api, repository, '0.6.0'), /No successful Release run of v0\.6\.0/);
  assert.throws(() => dispatchRun(fakeApi({ ...annotated, ...runs([]) }).api, repository, '0.6.0'), /No successful Release run/);
});

test('by hand, a version that is no release version is refused before the API is asked', () => {
  for (const version of ['0.6', 'main', '0.6.0/../../x', '']) {
    const { api, asked } = fakeApi({});
    assert.throws(() => dispatchRun(api, repository, version), assert.AssertionError, version);
    assert.deepEqual(asked, [], version);
  }
});
