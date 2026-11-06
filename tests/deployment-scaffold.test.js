import { expect, test } from 'bun:test';
import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dir, '..');
const template = readFileSync(resolve(root, '.github/workflow-templates/terraform-dev.yml.example'), 'utf8');

test('deployment scaffold stays inactive, dev-only and without cloud or artifact permissions', () => {
  const workflow = Bun.YAML.parse(template);
  expect(existsSync(resolve(root, '.github/workflows/terraform-dev.yml'))).toBe(false);
  expect(Object.keys(workflow.on)).toEqual(['workflow_dispatch']);
  expect(workflow.on.workflow_dispatch.inputs.stage.options).toEqual(['plan', 'apply']);
  expect(workflow.permissions).toEqual({ contents: 'read' });
  expect(workflow.concurrency).toEqual({ group: 'terraform-dev', 'cancel-in-progress': false });
  expect(workflow.env.TF_ROOT).toBe('environments/dev');
  expect(Object.keys(workflow.jobs)).toEqual(['prepare']);
  const job = workflow.jobs.prepare;
  expect(job.if).toBe('${{ false }}');
  expect(job.permissions).toBeUndefined();
  expect(job.steps.filter(step => step.uses).map(step => step.uses)).toEqual(['actions/checkout@v7']);
  const scripts = job.steps.map(step => step.run ?? '').join('\n');
  expect(scripts).toContain('^[0-9a-f]{40}$');
  expect(scripts).toContain('^[0-9a-f]{64}$');
  expect(scripts).toContain('git merge-base --is-ancestor "$SOURCE_SHA" refs/remotes/origin/main');
  expect(job.steps.at(-1).run.trim().endsWith('exit 1')).toBe(true);
  expect(scripts).not.toMatch(/\b(?:terraform|az|curl|wget|age|gh)\s/);
  expect(template).not.toContain('id-token: write');
});
