import { expect, test } from 'bun:test';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { checkCallerPlans } from './terraform-contracts.js';

const subscription = '/subscriptions/11111111-1111-1111-1111-111111111111';
const principals = ['22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333'];
const resource = (address, after) => ({ address, type: 'azapi_resource', change: { after } });
const eventsFor = (run, plan) => [
  { type: 'test_run', '@testfile': 'tests/contract.tftest.hcl', '@testrun': run, test_run: { progress: 'complete', status: 'pass' } },
  { type: 'test_plan', '@testfile': 'tests/contract.tftest.hcl', '@testrun': run, test_plan: plan },
];
const summary = { type: 'test_summary', test_summary: { status: 'pass' } };
const encode = events => events.map(event => JSON.stringify(event)).join('\n');

function environmentEvents() {
  const group = `${subscription}/resourceGroups/rg-pipesor-qa`;
  const network = { id: `${group}/providers/Microsoft.Network/virtualNetworks/network`, parent_id: group, location: 'workloadregion', body: { properties: { addressSpace: { addressPrefixes: ['10.50.0.0/16'] } } } };
  const subnet = { id: `${network.id}/subnets/subnet`, parent_id: network.id, body: { properties: { addressPrefix: '10.50.1.0/24' } } };
  const workspace = { id: `${group}/providers/Microsoft.OperationalInsights/workspaces/logs`, parent_id: group, location: 'workloadregion', body: { properties: { retentionInDays: 45, workspaceCapping: { dailyQuotaGb: 0.5 } } } };
  const platform = { id: `${group}/providers/Microsoft.App/managedEnvironments/platform`, parent_id: group, location: 'workloadregion', body: { properties: { vnetConfiguration: { infrastructureSubnetId: subnet.id } } } };
  const enabled = {
    resource_changes: [
      resource('module.resource_group.module.resource_group.azapi_resource.this', { parent_id: subscription, location: 'testregion' }),
      ...Object.entries({ network, subnet, workspace, environment: platform }).map(([name, value]) => resource(`module.container_platform[0].azapi_resource.${name}`, value)),
    ],
    output_changes: { container_platform: { after: { environment_id: platform.id, infrastructure_subnet_id: subnet.id, workspace_id: workspace.id, network_id: network.id } } },
  };
  const pgPrefix = 'module.postgresql[0].azapi_resource.';
  const databasePlan = { resource_changes: [
    resource('module.container_platform[0].azapi_resource.network', network),
    resource(pgPrefix + 'subnet', { parent_id: network.id, body: { properties: { addressPrefix: '10.50.2.0/28' } } }),
    resource(pgPrefix + 'server', { parent_id: group, location: 'workloadregion', name: 'test-pipesor-qa-pg', body: { properties: { authConfig: { tenantId: subscription.split('/')[2] } } } }),
    resource(pgPrefix + 'administrator', { name: principals[0] }),
  ] };
  return [...eventsFor('qa_root_contract', { resource_changes: [] }), ...eventsFor('opt_in_platform_contract', enabled), ...eventsFor('opt_in_postgresql_contract', databasePlan), ...eventsFor('opt_in_application_insights_contract', { resource_changes: [resource('module.container_platform[0].azapi_resource.workspace', workspace), resource('module.application_insights[0].azapi_resource.component', { parent_id: group, location: 'workloadregion', name: 'appipipesorqa', body: { properties: { WorkspaceResourceId: workspace.id, DisableLocalAuth: true } } })] }), summary];
}

function bootstrapEvents(environment = 'prod', account = 'pipesorstatefixtureprod') {
  const group = `${subscription}/resourceGroups/rg-pipesor-state-${environment}`;
  const container = { id: `${group}/providers/Microsoft.Storage/storageAccounts/fixture/blobServices/default/containers/tfstate-${environment}` };
  const prefix = 'module.state_store.module.';
  const plan = { resource_changes: [
    resource(prefix + 'resource_group.azapi_resource.this', { parent_id: subscription, location: 'testregion' }),
    resource(prefix + 'storage.azapi_resource.this', { parent_id: group, location: 'testregion', name: account, body: { sku: { name: 'Standard_ZRS' }, properties: { networkAcls: { ipRules: [{ value: '203.0.113.0/24' }, { value: '198.51.100.5' }] } } } }),
    resource(prefix + 'blob_service.azapi_update_resource.this', { body: { properties: { deleteRetentionPolicy: { days: 17 }, containerDeleteRetentionPolicy: { days: 17 } } } }),
    resource(prefix + 'container.azapi_resource.this', container),
    ...principals.map(principal => resource(`grant-${principal}`, { type: 'Microsoft.Authorization/roleAssignments@2022-04-01', parent_id: container.id, body: { properties: { principalId: principal, roleDefinitionId: `${subscription}/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe` } } })),
  ] };
  return [...eventsFor(`${environment}_bootstrap_isolation`, plan), summary];
}

function changedResource(events, suffix) {
  return events.filter(event => event.type === 'test_plan').flatMap(event => event.test_plan.resource_changes).find(change => change.address.endsWith(suffix)).change.after;
}

test('accepts valid caller plans with distinct IDs and unordered IP sets', () => {
  checkCallerPlans('environments/qa', encode(environmentEvents()));
  checkCallerPlans('bootstrap/prod', encode(bootstrapEvents()));
  checkCallerPlans('bootstrap/preprod', encode(bootstrapEvents('preprod', 'pipesorstatepreprod')));
});

test('rejects a passing native suite with a missing plan or resource', () => {
  const events = environmentEvents();
  expect(() => checkCallerPlans('environments/qa', encode(events.filter(event => event.type !== 'test_plan')))).toThrow('must emit exactly one plan');
  events.find(event => event['@testrun'] === 'opt_in_platform_contract' && event.type === 'test_plan').test_plan.resource_changes.pop();
  expect(() => checkCallerPlans('environments/qa', encode(events))).toThrow('Missing or duplicate planned resource');
});

test('rejects corrupted caller telemetry and resource IDs', () => {
  const cap = environmentEvents();
  changedResource(cap, '.workspace').body.properties.workspaceCapping.dailyQuotaGb = 99;
  expect(() => checkCallerPlans('environments/qa', encode(cap))).toThrow('Caller ingestion cap');
  const ids = environmentEvents();
  const output = ids.find(event => event['@testrun'] === 'opt_in_platform_contract' && event.type === 'test_plan').test_plan.output_changes.container_platform.after;
  output.environment_id = output.network_id;
  expect(() => checkCallerPlans('environments/qa', encode(ids))).toThrow('Caller resource ID exports');
  const unknown = environmentEvents();
  delete changedResource(unknown, '.environment').id;
  expect(() => checkCallerPlans('environments/qa', encode(unknown))).toThrow('Missing mocked resource ID');
});

test('rejects corrupted caller recovery, allowlist and principal scope', () => {
  const recovery = bootstrapEvents();
  changedResource(recovery, 'blob_service.azapi_update_resource.this').body.properties.deleteRetentionPolicy.days = 1;
  expect(() => checkCallerPlans('bootstrap/prod', encode(recovery))).toThrow('Caller recovery window');
  const ips = bootstrapEvents();
  changedResource(ips, 'storage.azapi_resource.this').body.properties.networkAcls.ipRules = [{ value: '198.51.100.99' }];
  expect(() => checkCallerPlans('bootstrap/prod', encode(ips))).toThrow('Caller operator allowlist');
  const scope = bootstrapEvents();
  changedResource(scope, 'grant-' + principals[0]).parent_id = subscription;
  expect(() => checkCallerPlans('bootstrap/prod', encode(scope))).toThrow('Caller principals, container scope and role');
});

test('rejects malformed output, absent success and failed required runs', () => {
  expect(() => checkCallerPlans('environments/qa', 'invalid JSON')).toThrow('malformed JSON');
  expect(() => checkCallerPlans('environments/qa', '')).toThrow('passing test summary');
  const events = environmentEvents();
  events[0].test_run.status = 'fail';
  expect(() => checkCallerPlans('environments/qa', encode(events))).toThrow('must complete successfully');
});

test('runner preserves Terraform failure even if its stdout looks successful', () => {
  const directory = mkdtempSync(join(tmpdir(), 'terraform-runner-test-'));
  try {
    writeFileSync(join(directory, 'events.jsonl'), encode(environmentEvents()));
    writeFileSync(join(directory, 'terraform'), '#!/bin/sh\ncat "$FAKE_TERRAFORM_EVENTS"\nexit 42\n', { mode: 0o700 });
    const result = Bun.spawnSync([process.execPath, resolve(import.meta.dir, 'terraform-contracts.js'), 'environments/qa'], { env: { ...process.env, PATH: `${directory}:${process.env.PATH}`, FAKE_TERRAFORM_EVENTS: join(directory, 'events.jsonl') }, stdout: 'pipe', stderr: 'pipe' });
    expect(result.exitCode).toBe(42);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test('rejects corrupted database caller VNet forwarding', () => {
  const events = environmentEvents();
  const plan = events.find(event => event.type === 'test_plan' && event['@testrun'] === 'opt_in_postgresql_contract').test_plan;
  plan.resource_changes.find(resource => resource.address === 'module.postgresql[0].azapi_resource.subnet').change.after.parent_id = subscription;
  expect(() => checkCallerPlans('environments/qa', encode(events))).toThrow('Database caller VNet');
});

test('rejects telemetry sent to another workspace', () => {
  const events = environmentEvents();
  const plan = events.find(event => event.type === 'test_plan' && event['@testrun'] === 'opt_in_application_insights_contract').test_plan;
  plan.resource_changes.find(item => item.address === 'module.application_insights[0].azapi_resource.component').change.after.body.properties.WorkspaceResourceId = 'wrong-workspace';
  expect(() => checkCallerPlans('environments/qa', encode(events))).toThrow('Telemetry caller workspace forwarding');
});
