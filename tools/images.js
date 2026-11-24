#!/usr/bin/env bun
// Versioned deployed images: environments/<env>/images.json (schema 1) pins every workload of an
// environment root by digest, with the candidate.json identity published by the service CI.
// Deploying, promoting or rolling back is a reviewed change to that file plus a fresh plan.
//
//   bun tools/images.js check
//   bun tools/images.js show <env>
//   bun tools/images.js set <env> <workload> --run <id> --attempt <n>
//   bun tools/images.js set <env> <workload> --release <vX.Y.Z[-rc.N]>
//   bun tools/images.js promote <from-env> <to-env> <workload...|--all>
import { execFileSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { parseArgs } from 'node:util';

export const ORGANIZATION = 'pipesor-org';
export const WORKLOADS = Object.freeze({
  ingestion: 'pipesor-ingestion-normalization-service',
  pipeline: 'pipesor-pipeline-service',
  'log-event': 'pipesor-log-event-service',
  nlp: 'pipesor-nlp-log-processor',
  correlation: 'pipesor-evidence-correlation-engine',
  recommendation: 'pipesor-recommendation-service',
  rag: 'pipesor-rag-retrieval',
  dashboard: 'pipesor-frontend',
});
const ENVIRONMENTS = ['dev', 'qa', 'preprod', 'prod'];
const DIGEST = /^sha256:[0-9a-f]{64}$/;
const SHA = /^[0-9a-f]{40}$/;
const POSITIVE = /^[1-9][0-9]*$/;
const RELEASE = /^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-rc\.[1-9][0-9]*)?$/;
const ENTRY_KEYS = ['image', 'digest', 'source_sha', 'build_run_id', 'build_run_attempt'];

function requireThat(condition, message) {
  if (!condition) throw new Error(message);
}

export const repositoryFor = workload => `${ORGANIZATION}/${WORKLOADS[workload]}`;
export const imageFor = workload => `ghcr.io/${repositoryFor(workload)}`;
export const reference = entry => `${entry.image}@${entry.digest}`;

export function validateEntry(workload, entry) {
  requireThat(Object.hasOwn(WORKLOADS, workload), `Unknown workload ${workload}`);
  requireThat(entry && typeof entry === 'object' && !Array.isArray(entry), `${workload}: entry must be an object`);
  requireThat(JSON.stringify(Object.keys(entry).sort()) === JSON.stringify([...ENTRY_KEYS].sort()),
    `${workload}: entry needs exactly ${ENTRY_KEYS.join(', ')}`);
  requireThat(entry.image === imageFor(workload), `${workload}: image must be ${imageFor(workload)}`);
  requireThat(DIGEST.test(entry.digest), `${workload}: digest must be sha256:<64 hex>`);
  requireThat(SHA.test(entry.source_sha), `${workload}: source_sha must be a full commit SHA`);
  for (const key of ['build_run_id', 'build_run_attempt']) {
    requireThat(typeof entry[key] === 'string' && POSITIVE.test(entry[key]), `${workload}: ${key} must be a positive integer string`);
  }
}

export function validateDocument(document, environment) {
  requireThat(ENVIRONMENTS.includes(environment), `Unknown environment ${environment}`);
  requireThat(document?.schema_version === 1, `${environment}: schema_version must be 1`);
  requireThat(document.environment === environment, `${environment}: environment field must be ${environment}`);
  const workloads = Object.keys(document.images ?? {});
  requireThat(JSON.stringify([...workloads].sort()) === JSON.stringify(Object.keys(WORKLOADS).sort()),
    `${environment}: images must cover exactly ${Object.keys(WORKLOADS).join(', ')}`);
  for (const workload of workloads) validateEntry(workload, document.images[workload]);
}

// A candidate is accepted only with the successful main push ci.yml attempt that produced it.
export function entryFromCandidate(workload, candidate, run) {
  const repository = repositoryFor(workload);
  requireThat(candidate?.schema_version === 1, 'candidate.json must use schema 1');
  requireThat(candidate.image === imageFor(workload), `Candidate image ${candidate.image} does not belong to ${workload}`);
  requireThat(DIGEST.test(candidate.digest ?? '') && SHA.test(candidate.source_sha ?? ''), 'Invalid candidate identity');
  requireThat(['build_run_id', 'build_run_attempt'].every(key => POSITIVE.test(candidate[key] ?? '')), 'Invalid candidate run');
  requireThat(String(run?.id) === candidate.build_run_id && String(run.run_attempt) === candidate.build_run_attempt
    && run.repository?.full_name === repository && run.head_sha === candidate.source_sha
    && run.event === 'push' && run.head_branch === 'main' && run.path === '.github/workflows/ci.yml'
    && run.status === 'completed' && run.conclusion === 'success',
  'Candidate does not come from a successful main push run of ci.yml');
  return Object.fromEntries(ENTRY_KEYS.map(key => [key, key === 'image' ? imageFor(workload) : candidate[key]]));
}

export function promote(source, target, workloads) {
  const result = structuredClone(target);
  for (const workload of workloads) {
    validateEntry(workload, source.images[workload]);
    result.images[workload] = structuredClone(source.images[workload]);
  }
  return result;
}

const documentPath = (root, environment) => join(root, 'environments', environment, 'images.json');

export function readDocument(root, environment) {
  const document = JSON.parse(readFileSync(documentPath(root, environment), 'utf8'));
  validateDocument(document, environment);
  return document;
}

export function writeDocument(root, environment, document) {
  validateDocument(document, environment);
  const ordered = { ...document, images: Object.fromEntries(Object.keys(WORKLOADS).map(w => [w, document.images[w]])) };
  writeFileSync(documentPath(root, environment), `${JSON.stringify(ordered, null, 2)}\n`);
}

export function environmentsWithImages(root) {
  return ENVIRONMENTS.filter(environment => existsSync(documentPath(root, environment)));
}

function gh(args) {
  return execFileSync('gh', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
}

function fetchCandidate(workload, { run, attempt, release }) {
  const repository = repositoryFor(workload);
  const directory = mkdtempSync(join(tmpdir(), 'pipesor-candidate-'));
  try {
    if (release) {
      requireThat(RELEASE.test(release), 'Release must be vX.Y.Z or vX.Y.Z-rc.N');
      const metadata = JSON.parse(gh(['api', `repos/${repository}/releases/tags/${release}`]));
      requireThat(metadata.tag_name === release && metadata.draft === false, 'Release must be published');
      gh(['release', 'download', release, '--repo', repository, '--pattern', 'candidate.json', '--dir', directory]);
    } else {
      requireThat(POSITIVE.test(run ?? '') && POSITIVE.test(attempt ?? ''), 'Use --run <id> --attempt <n> or --release <tag>');
      gh(['run', 'download', run, '--repo', repository, '--name', `candidate-${run}-${attempt}`, '--dir', directory]);
    }
    const candidate = JSON.parse(readFileSync(join(directory, 'candidate.json'), 'utf8'));
    if (release) {
      const commit = JSON.parse(gh(['api', `repos/${repository}/commits/${release}`]));
      requireThat(commit.sha === candidate.source_sha, 'Release tag and candidate source differ');
    }
    const ci = JSON.parse(gh(['api', `repos/${repository}/actions/runs/${candidate.build_run_id}/attempts/${candidate.build_run_attempt}`]));
    return entryFromCandidate(workload, candidate, ci);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}

function main(argv) {
  const { values, positionals } = parseArgs({
    args: argv, allowPositionals: true,
    options: { run: { type: 'string' }, attempt: { type: 'string' }, release: { type: 'string' },
      all: { type: 'boolean', default: false }, root: { type: 'string', default: '.' } },
  });
  const root = resolve(values.root);
  const [command, ...rest] = positionals;
  if (command === 'check') {
    const environments = environmentsWithImages(root);
    requireThat(environments.length > 0, 'No environments/*/images.json found');
    for (const environment of environments) readDocument(root, environment);
    console.log(`images.json valid for ${environments.join(', ')}`);
  } else if (command === 'show' && rest.length === 1) {
    const document = readDocument(root, rest[0]);
    for (const [workload, entry] of Object.entries(document.images)) {
      console.log(`${workload.padEnd(15)} ${reference(entry)}  source ${entry.source_sha.slice(0, 12)} run ${entry.build_run_id}/${entry.build_run_attempt}`);
    }
  } else if (command === 'set' && rest.length === 2) {
    const [environment, workload] = rest;
    requireThat(Object.hasOwn(WORKLOADS, workload), `Unknown workload ${workload}`);
    const document = readDocument(root, environment);
    const previous = document.images[workload];
    document.images[workload] = fetchCandidate(workload, values);
    writeDocument(root, environment, document);
    console.log(`${environment}/${workload}: ${reference(previous)} -> ${reference(document.images[workload])}`);
    console.log('Open a PR with this change, then generate, review and apply a fresh plan for that environment.');
  } else if (command === 'promote' && rest.length >= 2) {
    const [from, to, ...selected] = rest;
    const workloads = values.all ? Object.keys(WORKLOADS) : selected;
    requireThat(workloads.length > 0, 'Name the workloads to promote or pass --all');
    const target = promote(readDocument(root, from), readDocument(root, to), workloads);
    writeDocument(root, to, target);
    console.log(`Promoted ${workloads.join(', ')} from ${from} to ${to} with unchanged digests.`);
  } else {
    throw new Error('Usage: check | show <env> | set <env> <workload> (--run <id> --attempt <n> | --release <tag>) | promote <from> <to> <workload...|--all>');
  }
}

if (import.meta.main) {
  try {
    main(process.argv.slice(2));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
