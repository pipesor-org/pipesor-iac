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

function budgetEvents() {
  const id = `${subscription}/providers/Microsoft.Consumption/budgets/pipesor-monthly`;
  return [...eventsFor('budget_absent', { resource_changes: [] }), ...eventsFor('budget_contract', {
    resource_changes: [resource('azapi_resource.budget[0]', {
      id, name: 'pipesor-monthly', parent_id: subscription, type: 'Microsoft.Consumption/budgets@2024-08-01',
      body: { properties: {
        amount: 300, category: 'Cost', timeGrain: 'Monthly',
        timePeriod: { startDate: '2026-11-01T00:00:00Z', endDate: '2027-11-01T00:00:00Z' },
        notifications: Object.fromEntries([['actual_50',50,'Actual'],['actual_80',80,'Actual'],['actual_100',100,'Actual'],['forecast_100',100,'Forecasted']].map(([key,threshold,thresholdType]) => [key, {
          enabled: true, operator: 'GreaterThanOrEqualTo', threshold, thresholdType,
          contactEmails: ['FinOps+alerts@example.com', 'operators@example.com'], contactGroups: [], contactRoles: [],
        }])),
      } },
    })], output_changes: { budget: { after: { id, name: 'pipesor-monthly' } } },
  }), summary];
}

test('accepts subscription budget and rejects cost, scope, filter and automation regressions', () => {
  checkCallerPlans('subscription-controls', encode(budgetEvents()));
  for (const mutate of [
    value => { value.parent_id += '/resourceGroups/wrong-scope'; },
    value => { value.body.properties.amount = 1200; },
    value => { value.body.properties.filter = { tags: { name: 'environment', values: ['dev'] } }; },
    value => { value.body.properties.timeGrain = 'BillingMonth'; },
    value => { value.body.properties.notifications.actual_50.contactGroups = ['synthetic-action-group']; },
    value => { value.body.properties.notifications.forecast_100.thresholdType = 'Actual'; },
  ]) {
    const events = budgetEvents();
    mutate(events.find(event => event.type === 'test_plan' && event['@testrun'] === 'budget_contract').test_plan.resource_changes[0].change.after);
    expect(() => checkCallerPlans('subscription-controls', encode(events))).toThrow();
  }
});

test('rejects extra subscription controls and missing budget plans', () => {
  const events = budgetEvents();
  events.find(event => event.type === 'test_plan' && event['@testrun'] === 'budget_contract').test_plan.resource_changes.push(resource('azapi_resource.extra', {}));
  expect(() => checkCallerPlans('subscription-controls', encode(events))).toThrow('Only one subscription budget');
  expect(() => checkCallerPlans('subscription-controls', encode(budgetEvents().filter(event => event['@testrun'] !== 'budget_contract')))).toThrow('must complete successfully');
});

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
  const account = { id: `${group}/providers/Microsoft.CognitiveServices/accounts/test-pipesor-qa-ai`, parent_id: group, name: 'test-pipesor-qa-ai', location: 'airegion', tags: { environment: 'qa' }, body: { properties: { disableLocalAuth: true, publicNetworkAccess: 'Enabled' } }, output: { properties: { endpoint: 'synthetic' } } };
  const project = { id: `${account.id}/projects/pipesor-qa`, parent_id: account.id, name: 'pipesor-qa', location: 'airegion' };
  const foundry = { resource_changes: [resource('module.foundry[0].azapi_resource.account', account), resource('module.foundry[0].azapi_resource.project', project)], output_changes: { foundry: { after: { account_id: account.id, account_name: account.name, project_id: project.id, project_name: project.name, location: 'airegion', endpoint: 'synthetic' } } } };
  const web = { id: `${group}/providers/Microsoft.Web/staticSites/test-pipesor-qa-web`, parent_id: group, name: 'test-pipesor-qa-web', location: 'webregion', tags: { environment: 'qa' }, body: { sku: { name: 'Free', tier: 'Free' }, properties: { publicNetworkAccess: 'Enabled', enterpriseGradeCdnStatus: 'Disabled', stagingEnvironmentPolicy: 'Disabled', buildProperties: { skipGithubActionWorkflowGeneration: true } } }, output: { properties: { defaultHostname: 'synthetic.azurestaticapps.net' } } };
  const hosting = { resource_changes: [resource('module.static_web_app[0].azapi_resource.site', web)], output_changes: { static_web_app: { after: { id: web.id, name: web.name, location: 'webregion', default_hostname: 'synthetic.azurestaticapps.net' } } } };
  const combined = structuredClone({ resource_changes: [...enabled.resource_changes, ...databasePlan.resource_changes.filter(change => change.address.startsWith('module.postgresql')), ...foundry.resource_changes, ...hosting.resource_changes], output_changes: { ...enabled.output_changes, ...foundry.output_changes, ...hosting.output_changes } });
  const get = address => combined.resource_changes.find(change => change.address === address).change.after;
  const pg = get(pgPrefix + 'server');
  pg.id = `${group}/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-pipesor-qa-pg`;
  get(pgPrefix + 'subnet').id = `${network.id}/subnets/database`;
  pg.body.properties.network = { delegatedSubnetResourceId: get(pgPrefix + 'subnet').id, privateDnsZoneArmResourceId: `${group}/providers/Microsoft.Network/privateDnsZones/fixture` };
  pg.body.properties.authConfig.passwordAuth = 'Disabled';
  get('module.container_platform[0].azapi_resource.workspace').body.properties.features = { disableLocalAuth: true };
  combined.resource_changes.push(
    resource(pgPrefix + 'dns', { id: pg.body.properties.network.privateDnsZoneArmResourceId }),
    resource(pgPrefix + 'dns_link', { parent_id: pg.body.properties.network.privateDnsZoneArmResourceId, body: { properties: { virtualNetwork: { id: network.id } } } }),
    resource('module.container_platform[0].azapi_resource.logs', { body: { properties: { workspaceId: workspace.id } } }),
    resource('module.application_insights[0].azapi_resource.component', { id: `${group}/providers/Microsoft.Insights/components/appipipesorqa`, parent_id: group, location: 'workloadregion', body: { properties: { WorkspaceResourceId: workspace.id, DisableLocalAuth: true } } }),
    resource('module.service_bus[0].azapi_resource.namespace', { id: `${group}/providers/Microsoft.ServiceBus/namespaces/fixture`, parent_id: group, location: 'messagingregion', body: { properties: { disableLocalAuth: true } } }),
  );
  combined.output_changes.postgresql = { after: { id: pg.id, subnet_id: get(pgPrefix + 'subnet').id, private_dns_zone_id: pg.body.properties.network.privateDnsZoneArmResourceId } };
  combined.output_changes.application_insights = { after: { id: get('module.application_insights[0].azapi_resource.component').id, workspace_id: workspace.id } };
  combined.output_changes.service_bus = { after: { id: get('module.service_bus[0].azapi_resource.namespace').id } };
  return [...eventsFor('combined_foundations_contract', combined), ...eventsFor('opt_in_static_web_app_contract', hosting), ...eventsFor('opt_in_foundry_contract', foundry), ...eventsFor('qa_root_contract', { resource_changes: [] }), ...eventsFor('opt_in_platform_contract', enabled), ...eventsFor('opt_in_postgresql_contract', databasePlan), ...eventsFor('opt_in_application_insights_contract', { resource_changes: [resource('module.container_platform[0].azapi_resource.workspace', workspace), resource('module.application_insights[0].azapi_resource.component', { parent_id: group, location: 'workloadregion', name: 'appipipesorqa', body: { properties: { WorkspaceResourceId: workspace.id, DisableLocalAuth: true } } })] }), summary];
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
  return events.filter(event => event.type === 'test_plan' && event['@testrun'] !== 'combined_foundations_contract').flatMap(event => event.test_plan.resource_changes).find(change => change.address.endsWith(suffix)).change.after;
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

test('rejects Foundry caller security and project parenting regressions', () => {
  const auth = environmentEvents();
  changedResource(auth, 'module.foundry[0].azapi_resource.account').body.properties.disableLocalAuth = false;
  expect(() => checkCallerPlans('environments/qa', encode(auth))).toThrow('Foundry caller Entra authentication');
  const parent = environmentEvents();
  changedResource(parent, 'module.foundry[0].azapi_resource.project').parent_id = subscription;
  expect(() => checkCallerPlans('environments/qa', encode(parent))).toThrow('Foundry caller project parenting');
});

test('rejects unapproved resources added to Foundry scope', () => {
  const events = environmentEvents();
  events.find(event => event.type === 'test_plan' && event['@testrun'] === 'opt_in_foundry_contract').test_plan.resource_changes.push(resource('module.foundry[0].azapi_resource.deployment', {}));
  expect(() => checkCallerPlans('environments/qa', encode(events))).toThrow('Foundry scope contains only account and project');
});

test('rejects static hosting tier and repository integration regressions', () => {
  const tier = environmentEvents();
  changedResource(tier, 'module.static_web_app[0].azapi_resource.site').body.sku.name = 'Standard';
  expect(() => checkCallerPlans('environments/qa', encode(tier))).toThrow('Static hosting must remain Free');
  const repo = environmentEvents();
  changedResource(repo, 'module.static_web_app[0].azapi_resource.site').body.properties.repositoryToken = 'synthetic';
  expect(() => checkCallerPlans('environments/qa', encode(repo))).toThrow('Static hosting must remain Free');
});

test('rejects static hosting additions and wrong environment wiring', () => {
  const extra = environmentEvents();
  extra.find(event => event.type === 'test_plan' && event['@testrun'] === 'opt_in_static_web_app_contract').test_plan.resource_changes.push(resource('module.static_web_app[0].azapi_resource.domain', {}));
  expect(() => checkCallerPlans('environments/qa', encode(extra))).toThrow('Static hosting scope contains only one site');
  const parent = environmentEvents();
  changedResource(parent, 'module.static_web_app[0].azapi_resource.site').parent_id = subscription;
  expect(() => checkCallerPlans('environments/qa', encode(parent))).toThrow('Static hosting caller resource group');
});

function combinedResource(events, address) {
  return events.find(event => event.type === 'test_plan' && event['@testrun'] === 'combined_foundations_contract').test_plan.resource_changes.find(change => change.address === address).change.after;
}

test('rejects combined cross-environment parenting and shared dependency corruption', () => {
  for (const [address, corrupt, message] of [
    ['module.service_bus[0].azapi_resource.namespace', value => { value.parent_id = 'wrong-environment'; }, 'Combined foundation environment boundary'],
    ['module.postgresql[0].azapi_resource.subnet', value => { value.parent_id = 'wrong-vnet'; }, 'Combined database VNet'],
    ['module.application_insights[0].azapi_resource.component', value => { value.body.properties.WorkspaceResourceId = 'wrong-workspace'; }, 'Combined telemetry workspace'],
    ['module.foundry[0].azapi_resource.account', value => { value.body.properties.disableLocalAuth = false; }, 'Combined Entra-only security'],
    ['module.static_web_app[0].azapi_resource.site', value => { value.body.properties.repositoryToken = 'synthetic'; }, 'Combined static hosting security'],
  ]) {
    const events = environmentEvents();
    corrupt(combinedResource(events, address));
    expect(() => checkCallerPlans('environments/qa', encode(events))).toThrow(message);
  }
});

test('requires the combined plan and checks its output identity independently', () => {
  const events = environmentEvents();
  expect(() => checkCallerPlans('environments/qa', encode(events.filter(event => event['@testrun'] !== 'combined_foundations_contract')))).toThrow('must complete successfully');
  events.find(event => event.type === 'test_plan' && event['@testrun'] === 'combined_foundations_contract').test_plan.output_changes.postgresql.after.subnet_id = 'wrong-subnet';
  expect(() => checkCallerPlans('environments/qa', encode(events))).toThrow('Combined output wiring');
});

test('rejects unapproved resources and region changes in the combined plan', () => {
  for (const address of ['module.foundry[0].azapi_resource.model', 'azapi_resource.grant', 'module.container_platform[0].azapi_resource.extra_workspace']) {
    const events = environmentEvents();
    events.find(event => event.type === 'test_plan' && event['@testrun'] === 'combined_foundations_contract').test_plan.resource_changes.push(resource(address, {}));
    expect(() => checkCallerPlans('environments/qa', encode(events))).toThrow('Combined scope contains only approved foundation resources');
  }
  const events = environmentEvents();
  combinedResource(events, 'module.service_bus[0].azapi_resource.namespace').location = 'workloadregion';
  expect(() => checkCallerPlans('environments/qa', encode(events))).toThrow('Combined explicit region forwarding');
});
