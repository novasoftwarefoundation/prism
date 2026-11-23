import assert from 'node:assert/strict';
import { test } from 'node:test';
import { releaseRun, tagOf } from './release-run.mjs';

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
