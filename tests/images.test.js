import { expect, test } from 'bun:test';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import {
  WORKLOADS, entryFromCandidate, environmentsWithImages, imageFor, promote, readDocument, validateDocument,
} from '../tools/images.js';

const root = resolve(import.meta.dir, '..');
const script = join(root, 'tools/images.js');

function entry(workload, digit = 'a') {
  return { image: imageFor(workload), digest: `sha256:${digit.repeat(64)}`, source_sha: digit.repeat(40),
    build_run_id: '42', build_run_attempt: '1' };
}

function document(environment, digit = 'a') {
  return { schema_version: 1, environment,
    images: Object.fromEntries(Object.keys(WORKLOADS).map(workload => [workload, entry(workload, digit)])) };
}

test('committed images.json files are valid and pin every workload by digest', () => {
  const environments = environmentsWithImages(root);
  expect(environments).toContain('dev');
  for (const environment of environments) {
    const images = readDocument(root, environment).images;
    expect(Object.keys(images)).toEqual(Object.keys(WORKLOADS));
  }
});

test('documents reject missing, foreign or malformed entries', () => {
  expect(() => validateDocument(document('dev'), 'dev')).not.toThrow();
  const cases = [
    doc => { doc.schema_version = 2; },
    doc => { doc.environment = 'qa'; },
    doc => { delete doc.images.rag; },
    doc => { doc.images.extra = entry('rag'); },
    doc => { doc.images.rag.image = imageFor('nlp'); },
    doc => { doc.images.rag.image = 'docker.io/library/rag'; },
    doc => { doc.images.rag.digest = 'sha256:short'; },
    doc => { doc.images.rag.digest = `sha256:${'A'.repeat(64)}`; },
    doc => { doc.images.rag.source_sha = 'main'; },
    doc => { doc.images.rag.build_run_id = 42; },
    doc => { doc.images.rag.build_run_attempt = '0'; },
    doc => { doc.images.rag.tag = 'latest'; },
  ];
  for (const mutate of cases) {
    const invalid = document('dev');
    mutate(invalid);
    expect(() => validateDocument(invalid, 'dev')).toThrow();
  }
  expect(() => validateDocument(document('staging'), 'staging')).toThrow('Unknown environment');
});

const candidate = { schema_version: 1, source_sha: 'c'.repeat(40), image: imageFor('pipeline'),
  digest: `sha256:${'d'.repeat(64)}`, build_run_id: '77', build_run_attempt: '2' };
const run = { id: 77, run_attempt: 2, repository: { full_name: 'pipesor-org/pipesor-pipeline-service' },
  head_sha: candidate.source_sha, event: 'push', head_branch: 'main', path: '.github/workflows/ci.yml',
  status: 'completed', conclusion: 'success' };

test('candidates become entries only with their successful main CI attempt', () => {
  expect(entryFromCandidate('pipeline', candidate, run)).toEqual({ image: candidate.image, digest: candidate.digest,
    source_sha: candidate.source_sha, build_run_id: '77', build_run_attempt: '2' });
  for (const update of [{ conclusion: 'failure' }, { event: 'pull_request' }, { head_branch: 'feature/x' },
    { path: '.github/workflows/release.yml' }, { run_attempt: 1 }, { head_sha: 'e'.repeat(40) },
    { repository: { full_name: 'pipesor-org/pipesor-rag-retrieval' } }]) {
    expect(() => entryFromCandidate('pipeline', candidate, { ...run, ...update })).toThrow();
  }
  expect(() => entryFromCandidate('rag', candidate, run)).toThrow('does not belong');
  expect(() => entryFromCandidate('pipeline', { ...candidate, schema_version: 2 }, run)).toThrow('schema 1');
});

test('promotion copies the exact digest and leaves other workloads untouched', () => {
  const dev = document('dev', 'a');
  const qa = document('qa', 'b');
  const promoted = promote(dev, qa, ['pipeline']);
  expect(promoted.images.pipeline).toEqual(dev.images.pipeline);
  expect(promoted.images.rag).toEqual(qa.images.rag);
  expect(qa.images.pipeline.digest).toBe(`sha256:${'b'.repeat(64)}`);
  expect(promoted.environment).toBe('qa');
});

test('CLI checks, shows and promotes local documents without network access', () => {
  const directory = mkdtempSync(join(tmpdir(), 'pipesor-images-'));
  try {
    for (const environment of ['dev', 'qa']) {
      mkdirSync(join(directory, 'environments', environment), { recursive: true });
      writeFileSync(join(directory, 'environments', environment, 'images.json'),
        `${JSON.stringify(document(environment, environment === 'dev' ? 'a' : 'b'), null, 2)}\n`);
    }
    const cli = (...args) => spawnSync(process.execPath, [script, ...args, '--root', directory], { encoding: 'utf8' });
    expect(cli('check').status).toBe(0);
    expect(cli('show', 'dev').stdout).toContain(`${imageFor('pipeline')}@sha256:${'a'.repeat(64)}`);
    expect(cli('promote', 'dev', 'qa').status).toBe(1);
    expect(cli('promote', 'dev', 'qa', 'pipeline').status).toBe(0);
    const qa = JSON.parse(readFileSync(join(directory, 'environments/qa/images.json'), 'utf8'));
    expect(qa.images.pipeline.digest).toBe(`sha256:${'a'.repeat(64)}`);
    expect(qa.images.rag.digest).toBe(`sha256:${'b'.repeat(64)}`);
    expect(Object.keys(qa.images)).toEqual(Object.keys(WORKLOADS));
    writeFileSync(join(directory, 'environments/qa/images.json'), '{"schema_version":1}');
    expect(cli('check').status).toBe(1);
    expect(cli('set', 'dev', 'pipeline').status).toBe(1);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});
