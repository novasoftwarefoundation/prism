// The Release run a publish workflow publishes from: the run of release.yml that a version
// tag's push started in this repository and that succeeded, at the commit the tag points at.
// On `workflow_run` it is the run that started the workflow; started by hand
// (`workflow_dispatch`) with a version, it is the newest such run for that version's tag.
// It writes the tag, the version, the commit and the run's id to GITHUB_OUTPUT, so the
// workflow checks out that commit and downloads that run's `prism-release` artifact, and
// fails when there is no such run.
//
//   GITHUB_EVENT_NAME=workflow_run RELEASE_RUN='<the event's workflow_run>' node .github/release-run.mjs
//   GITHUB_EVENT_NAME=workflow_dispatch VERSION=X.Y.Z node .github/release-run.mjs
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { appendFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { releaseVersion } from './release-version.mjs';

export const releaseWorkflow = '.github/workflows/release.yml';

// The run, checked: release.yml's, started by the push of `tag` in `repository`, a success,
// at `tagCommit`, the commit the tag points at now.
export function releaseRun(run, { repository, tag, tagCommit }) {
  const { version } = releaseVersion(tag);
  assert.equal(run?.path?.split('@')[0], releaseWorkflow, 'The run is not one of release.yml');
  assert.equal(run.event, 'push', 'The Release run was not started by a push');
  assert.equal(run.repository?.full_name, repository, 'The Release run is another repository\'s');
  assert.equal(run.head_repository?.full_name, repository, 'The Release run is of another repository\'s commit');
  assert.equal(run.head_branch, tag, `The Release run is not ${tag}'s`);
  assert.equal(run.conclusion, 'success', 'The Release run did not succeed');
  assert.equal(run.head_sha, tagCommit, `The Release run is not at the commit ${tag} points at`);
  assert.ok(Number.isSafeInteger(run.id), 'The Release run has no id');
  return { tag, version, commit: run.head_sha, runId: run.id };
}

// The version typed in by hand, as its tag: X.Y.Z or vX.Y.Z.
export const tagOf = (version) => (version.startsWith('v') ? version : `v${version}`);

// The commit a tag points at, through `api` (a GET of a REST path, giving its JSON): an
// annotated tag's ref points at the tag object, and that one at the commit.
export function commitOf(api, repository, tag) {
  let { object } = api(`repos/${repository}/git/ref/tags/${tag}`);
  while (object.type === 'tag') ({ object } = api(`repos/${repository}/git/tags/${object.sha}`));
  assert.equal(object.type, 'commit', `${tag} points at no commit`);
  return object.sha;
}

// By hand: the newest successful Release run of the version's tag at the commit the tag points
// at, and that commit. GitHub lists the runs newest first.
export function dispatchRun(api, repository, version) {
  const tag = tagOf(version);
  releaseVersion(tag);
  const tagCommit = commitOf(api, repository, tag);
  const { workflow_runs: runs } = api(
    `repos/${repository}/actions/workflows/release.yml/runs?event=push&branch=${tag}&status=success&per_page=100`,
  );
  const run = runs.find((candidate) => candidate.head_sha === tagCommit);
  assert.ok(run, `No successful Release run of ${tag} at ${tagCommit}: release it first`);
  return { run, tag };
}

function main() {
  const repository = process.env.GITHUB_REPOSITORY;
  const api = (path) => JSON.parse(execFileSync('gh', ['api', path], { encoding: 'utf8' }));

  let run;
  let tag;
  if (process.env.GITHUB_EVENT_NAME === 'workflow_dispatch') {
    ({ run, tag } = dispatchRun(api, repository, process.env.VERSION ?? ''));
  } else {
    assert.equal(process.env.GITHUB_EVENT_NAME, 'workflow_run', 'Started by neither workflow_run nor workflow_dispatch');
    run = JSON.parse(process.env.RELEASE_RUN);
    tag = run.head_branch;
  }
  const { version, commit, runId } = releaseRun(run, { repository, tag, tagCommit: commitOf(api, repository, tag) });
  appendFileSync(process.env.GITHUB_OUTPUT, `tag=${tag}\nversion=${version}\ncommit=${commit}\nrun-id=${runId}\n`);
  console.log(`Publishing ${tag} (${commit}) from Release run ${run.html_url ?? runId}.`);
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) main();
