import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { appendFileSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

const schema = 1;
const packages = ['targets/swift/', 'generator/test/fixtures/swift/', 'design/test/swiftui/'];
const ignored = new Set(['targets/swift/README.md', 'targets/swift/LICENSE', 'targets/swift/.gitignore']);
const controls = new Set([
  '.tool-versions', '.github/workflows/ci.yml', '.github/workflows/release.yml',
  '.github/swift-validation.mjs', '.github/swift-validation.test.mjs',
]);
const workflows = new Set(['.github/workflows/ci.yml', '.github/workflows/release.yml']);

export function isSwiftInput(path) {
  return controls.has(path) || (packages.some(prefix => path.startsWith(prefix)) && !ignored.has(path));
}

export function fingerprint(files, environment) {
  const inputs = [...files].filter(([path]) => isSwiftInput(path))
    .sort(([a], [b]) => a.localeCompare(b, 'en'))
    .map(([path, bytes]) => [path, createHash('sha256').update(bytes).digest('hex')]);
  for (const prefix of packages) {
    if (!inputs.some(([path]) => path.startsWith(prefix) && path.endsWith('/Package.swift'))) {
      throw new Error(`Missing Swift package input: ${prefix}`);
    }
  }
  for (const path of controls) {
    if (!inputs.some(([name]) => path === name)) throw new Error(`Missing validation control: ${path}`);
  }
  const value = { schema, environment, inputs };
  return { ...value, fingerprint: createHash('sha256').update(JSON.stringify(value)).digest('hex') };
}

export function verifiedRecord(artifact, run, jobs, record, expected, repository) {
  const swift = jobs.find(job => job.name === 'Swift package (iOS Simulator)' ||
    job.name.endsWith(' / Swift package (iOS Simulator)'));
  return artifact.expired === false && artifact.workflow_run?.id === run.id &&
    artifact.workflow_run?.repository_id === run.repository?.id &&
    artifact.workflow_run?.head_repository_id === run.repository?.id &&
    run.repository?.full_name === repository && run.head_repository?.id === run.repository.id &&
    workflows.has(run.path?.split('@')[0]) && ['push', 'pull_request'].includes(run.event) &&
    run.status === 'completed' && run.conclusion === 'success' &&
    record.schema === schema && record.repository === repository &&
    record.runId === run.id && record.runAttempt === run.run_attempt &&
    record.fingerprint === expected.fingerprint &&
    JSON.stringify(record.environment) === JSON.stringify(expected.environment) &&
    JSON.stringify(record.inputs) === JSON.stringify(expected.inputs) &&
    swift?.conclusion === 'success' &&
    ['Build the packages', "Render Prism's components", 'Record successful Swift validation']
      .every(name => swift.steps?.some(step => step.name === name && step.conclusion === 'success'));
}

export async function findValidation(expected, repository, api, currentRun) {
  const name = `swift-validation-${expected.fingerprint}`;
  // A missing/expired/unreadable record costs a test run, never a skipped gate.
  try {
    for (let page = 1; page <= 5; page++) {
      const result = await api.artifacts(name, page);
      for (const artifact of result.artifacts) {
        if (artifact.name !== name || artifact.expired || artifact.workflow_run?.id === currentRun) continue;
        try {
          const run = await api.run(artifact.workflow_run.id);
          if (run.status !== 'completed' || run.conclusion !== 'success') continue;
          const jobs = await api.jobs(run.id);
          const record = await api.record(artifact);
          if (verifiedRecord(artifact, run, jobs, record, expected, repository)) return run;
        } catch { /* Invalid evidence is not a validation pass. Try another record. */ }
      }
      if (result.artifacts.length < 100) break;
    }
  } catch (error) {
    console.warn(`Swift validation lookup unavailable; running the suite: ${error.message}`);
  }
  return null;
}

const command = (binary, args) => execFileSync(binary, args, { encoding: 'utf8', maxBuffer: 1024 * 1024 });
const json = args => JSON.parse(command('gh', ['api', ...args]));

function environment() {
  const image = process.env.ImageVersion;
  if (!image) throw new Error('Runner ImageVersion is required to identify the Swift test environment');
  const devices = JSON.parse(command('xcrun', ['simctl', 'list', 'devices', 'available', '-j'])).devices;
  const choice = Object.entries(devices).flatMap(([runtime, entries]) =>
    entries.filter(device => device.isAvailable && device.name.startsWith('iPhone'))
      .map(device => ({ runtime, device }))).at(0);
  if (!choice) throw new Error('No available iPhone simulator');
  const runtime = JSON.parse(command('xcrun', ['simctl', 'list', 'runtimes', '-j'])).runtimes
    .find(value => value.identifier === choice.runtime);
  if (!runtime?.buildversion) throw new Error('Simulator runtime build is unknown');
  return {
    identity: {
      runnerImage: image, osBuild: command('sw_vers', ['-buildVersion']).trim(),
      xcode: command('xcodebuild', ['-version']).trim(), node: process.version, arch: process.arch,
      simulatorRuntime: runtime.identifier, simulatorBuild: runtime.buildversion,
      deviceType: choice.device.deviceTypeIdentifier || choice.device.name,
    },
    simulator: choice.device.udid,
  };
}

function api(repository, directory) {
  const base = `repos/${repository}/actions`;
  return {
    artifacts: (name, page) => json([`${base}/artifacts?name=${name}&per_page=100&page=${page}`]),
    run: id => json([`${base}/runs/${id}`]),
    jobs: id => json(['--paginate', '--slurp', `${base}/runs/${id}/jobs?filter=latest&per_page=100`])
      .flatMap(page => page.jobs),
    record: artifact => {
      if (artifact.size_in_bytes > 1024 * 1024 || !/^sha256:[a-f0-9]{64}$/.test(artifact.digest || '')) {
        throw new Error('Invalid validation artifact size/digest');
      }
      const bytes = execFileSync('gh', ['api', `${base}/artifacts/${artifact.id}/zip`], { maxBuffer: 1024 * 1024 });
      if (`sha256:${createHash('sha256').update(bytes).digest('hex')}` !== artifact.digest) {
        throw new Error('Validation artifact digest mismatch');
      }
      const archive = join(directory, 'swift-validation.zip');
      writeFileSync(archive, bytes);
      if (command('unzip', ['-Z', '-1', archive]).trim() !== 'verification.json') {
        throw new Error('Unexpected validation artifact files');
      }
      return JSON.parse(command('unzip', ['-p', archive, 'verification.json']));
    },
  };
}

async function main(mode) {
  const directory = join(process.env.RUNNER_TEMP, 'swift-validation');
  mkdirSync(directory, { recursive: true });
  const planPath = join(directory, 'inputs.json');
  const repository = process.env.GITHUB_REPOSITORY;
  const runId = Number(process.env.GITHUB_RUN_ID);
  const runAttempt = Number(process.env.GITHUB_RUN_ATTEMPT);
  if (!repository || !Number.isSafeInteger(runId) || !Number.isSafeInteger(runAttempt)) {
    throw new Error('Missing workflow identity');
  }
  if (mode === 'plan') {
    const runtime = environment();
    const paths = command('git', ['ls-files', '-z']).split('\0').filter(isSwiftInput);
    const expected = fingerprint(paths.map(path => [path, readFileSync(path)]), runtime.identity);
    writeFileSync(planPath, JSON.stringify(expected, null, 2));
    const previous = await findValidation(expected, repository, api(repository, directory), runId);
    appendFileSync(process.env.GITHUB_OUTPUT,
      `fingerprint=${expected.fingerprint}\nreuse=${Boolean(previous)}\nsimulator=${runtime.simulator}\n`);
    const result = previous ? `Reusing [successful Swift run](${previous.html_url}).` : 'No matching successful record; running Swift builds and simulator tests.';
    appendFileSync(process.env.GITHUB_STEP_SUMMARY,
      `### Swift validation\n\nInputs/environment: \`${expected.fingerprint}\`\n\n${result}\n`);
    console.log(result);
  } else if (mode === 'record') {
    const expected = JSON.parse(readFileSync(planPath));
    const record = {
      ...expected, repository, runId, runAttempt,
      checkoutCommit: command('git', ['rev-parse', 'HEAD']).trim(),
    };
    const output = join(directory, 'record');
    mkdirSync(output, { recursive: true });
    writeFileSync(join(output, 'verification.json'), JSON.stringify(record, null, 2));
  } else throw new Error(`Unknown mode: ${mode}`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main(process.argv[2]).catch(error => { console.error(error.message); process.exitCode = 1; });
}
