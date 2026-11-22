import { expect, test } from 'bun:test';
import { mkdtempSync, writeFileSync, rmSync, readFileSync } from 'node:fs';
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
  const account = { id: `${group}/providers/Microsoft.CognitiveServices/accounts/test-pipesor-qa-ai`, parent_id: group, name: 'test-pipesor-qa-ai', location: 'airegion', tags: { environment: 'qa' }, body: { properties: { disableLocalAuth: true, publicNetworkAccess: 'Enabled' } }, output: { properties: { endpoint: 'synthetic' } } };
  const project = { id: `${account.id}/projects/pipesor-qa`, parent_id: account.id, name: 'pipesor-qa', location: 'airegion' };
  const foundry = { resource_changes: [resource('module.foundry[0].azapi_resource.account', account), resource('module.foundry[0].azapi_resource.project', project)], output_changes: { foundry: { after: { account_id: account.id, account_name: account.name, project_id: project.id, project_name: project.name, location: 'airegion', endpoint: 'synthetic', deployments: {} } } } };
  const web = { id: `${group}/providers/Microsoft.Web/staticSites/test-pipesor-qa-web`, parent_id: group, name: 'test-pipesor-qa-web', location: 'webregion', tags: { environment: 'qa' }, body: { sku: { name: 'Free', tier: 'Free' }, properties: { publicNetworkAccess: 'Enabled', enterpriseGradeCdnStatus: 'Disabled', stagingEnvironmentPolicy: 'Disabled', buildProperties: { skipGithubActionWorkflowGeneration: true } } }, output: { properties: { defaultHostname: 'synthetic.azurestaticapps.net' } } };
  const hosting = { resource_changes: [resource('module.static_web_app[0].azapi_resource.site', web)], output_changes: { static_web_app: { after: { id: web.id, name: web.name, location: 'webregion', default_hostname: 'synthetic.azurestaticapps.net' } } } };
  const vaultPrefix = 'module.key_vault[0].azapi_resource.';
  const vaultProperties = {
    tenantId: '44444444-4444-4444-4444-444444444444', sku: { family: 'A', name: 'standard' }, accessPolicies: [],
    enableRbacAuthorization: true, enableSoftDelete: true, enablePurgeProtection: true, softDeleteRetentionInDays: 30,
    enabledForDeployment: false, enabledForDiskEncryption: false, enabledForTemplateDeployment: false, publicNetworkAccess: 'Enabled',
    networkAcls: { bypass: 'None', defaultAction: 'Deny', ipRules: [{ value: '203.0.113.5/32' }], virtualNetworkRules: [] },
  };
  const vault = (purpose, suffix) => ({ id: `${group}/providers/Microsoft.KeyVault/vaults/test-pipesor-qa-${suffix}`, type: 'Microsoft.KeyVault/vaults@2024-11-01', parent_id: group, name: `test-pipesor-qa-${suffix}`, location: 'vaultregion', tags: { environment: 'qa', purpose }, body: { properties: structuredClone(vaultProperties) }, response_export_values: ['properties.vaultUri'], output: { properties: { vaultUri: `https://test-pipesor-qa-${suffix}.vault.azure.net/` } } });
  const appVault = vault('app_material', 'app');
  const custodyVault = vault('custody', 'usr');
  const definition = { id: `${subscription}/providers/Microsoft.Authorization/roleDefinitions/55555555-5555-5555-5555-555555555555`, parent_id: subscription, body: { properties: { assignableScopes: [group], permissions: [{ actions: [], notActions: [], notDataActions: [], dataActions: ['Microsoft.KeyVault/vaults/secrets/getSecret/action', 'Microsoft.KeyVault/vaults/secrets/setSecret/action'] }] } } };
  const vaultPlan = { resource_changes: [
    resource(vaultPrefix + 'vault["app_material"]', appVault), resource(vaultPrefix + 'vault["custody"]', custodyVault),
    resource(vaultPrefix + 'app_material_reader["developer"]', { parent_id: appVault.id, body: { properties: { principalId: principals[0], principalType: 'User', roleDefinitionId: `${subscription}/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6` } } }),
    resource(vaultPrefix + 'custody_role[0]', definition),
    resource(vaultPrefix + 'custody_writer["ingestion"]', { parent_id: custodyVault.id, body: { properties: { principalId: principals[1], principalType: 'ServicePrincipal', roleDefinitionId: definition.id } } }),
  ], output_changes: { key_vault: { after: Object.fromEntries([[appVault, 'app_material'], [custodyVault, 'custody']].map(([item, purpose]) => [purpose, { id: item.id, name: item.name, location: 'vaultregion', tenant_id: vaultProperties.tenantId, uri: item.output.properties.vaultUri }])) } } };
  const appOnly = { resource_changes: [resource(vaultPrefix + 'vault["app_material"]', appVault)] };
  const combined = structuredClone({ resource_changes: [...enabled.resource_changes, ...databasePlan.resource_changes.filter(change => change.address.startsWith('module.postgresql')), ...foundry.resource_changes, ...hosting.resource_changes, ...vaultPlan.resource_changes], output_changes: { ...enabled.output_changes, ...foundry.output_changes, ...hosting.output_changes, ...vaultPlan.output_changes } });
  const get = address => combined.resource_changes.find(change => change.address === address).change.after;
  get('module.container_platform[0].azapi_resource.subnet').body.properties.serviceEndpoints = [{ service: 'Microsoft.KeyVault' }];
  for (const purpose of ['app_material', 'custody']) get(vaultPrefix + `vault["${purpose}"]`).body.properties.networkAcls.virtualNetworkRules = [{ id: subnet.id, ignoreMissingVnetServiceEndpoint: false }];
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
  return [...eventsFor('opt_in_key_vault_contract', vaultPlan), ...eventsFor('app_material_only_key_vault_contract', appOnly), ...eventsFor('combined_foundations_contract', combined), ...eventsFor('opt_in_static_web_app_contract', hosting), ...eventsFor('opt_in_foundry_contract', foundry), ...eventsFor('qa_root_contract', { resource_changes: [] }), ...eventsFor('opt_in_platform_contract', enabled), ...eventsFor('opt_in_postgresql_contract', databasePlan), ...eventsFor('opt_in_application_insights_contract', { resource_changes: [resource('module.container_platform[0].azapi_resource.workspace', workspace), resource('module.application_insights[0].azapi_resource.component', { parent_id: group, location: 'workloadregion', name: 'appipipesorqa', body: { properties: { WorkspaceResourceId: workspace.id, DisableLocalAuth: true } } })] }), summary];
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


test('rejects Key Vault payloads, weak recovery, bypass and wrong tenant', () => {
  for (const corrupt of [
    value => { value.body.properties.secretValue = 'synthetic'; },
    value => { value.body.properties.enablePurgeProtection = false; },
    value => { value.body.properties.networkAcls.bypass = 'AzureServices'; },
    value => { value.body.properties.tenantId = principals[0]; },
  ]) {
    const events = environmentEvents();
    corrupt(changedResource(events, 'vault["app_material"]'));
    expect(() => checkCallerPlans('environments/qa', encode(events))).toThrow('Key Vault security and absence of secret payloads');
  }
});

test('rejects overprivileged custody and cross-vault grants', () => {
  const scope = environmentEvents();
  changedResource(scope, 'custody_writer["ingestion"]').parent_id = changedResource(scope, 'vault["app_material"]').id;
  expect(() => checkCallerPlans('environments/qa', encode(scope))).toThrow('Credential writer custody-only scope');
  const permissions = environmentEvents();
  changedResource(permissions, 'custody_role[0]').body.properties.permissions[0].dataActions.push('Microsoft.KeyVault/vaults/secrets/delete');
  expect(() => checkCallerPlans('environments/qa', encode(permissions))).toThrow('Credential runtime get/set only');
});

test('rejects Key Vault opt-out activation and secret resources', () => {
  const baseline = environmentEvents();
  baseline.find(event => event.type === 'test_plan' && event['@testrun'] === 'qa_root_contract').test_plan.resource_changes.push(resource('module.key_vault[0].azapi_resource.vault["app_material"]', {}));
  expect(() => checkCallerPlans('environments/qa', encode(baseline))).toThrow('Opt-out must plan no Key Vault');
  const payload = environmentEvents();
  payload.find(event => event.type === 'test_plan' && event['@testrun'] === 'opt_in_key_vault_contract').test_plan.resource_changes.push(resource('module.key_vault[0].azapi_resource.secret', {}));
  expect(() => checkCallerPlans('environments/qa', encode(payload))).toThrow('Key Vault scope contains only vaults and explicit scoped grants');
});

test('rejects combined missing service endpoints and missing-endpoint bypass', () => {
  const absent = environmentEvents();
  delete combinedResource(absent, 'module.container_platform[0].azapi_resource.subnet').body.properties.serviceEndpoints;
  expect(() => checkCallerPlans('environments/qa', encode(absent))).toThrow('Combined ACA Key Vault service endpoint');
  const bypass = environmentEvents();
  combinedResource(bypass, 'module.key_vault[0].azapi_resource.vault["custody"]').body.properties.networkAcls.virtualNetworkRules[0].ignoreMissingVnetServiceEndpoint = true;
  expect(() => checkCallerPlans('environments/qa', encode(bypass))).toThrow('Key Vault security and absence of secret payloads');
});


test('ACA replacement tracks subnet identity rather than service endpoint updates', () => {
  const source = readFileSync(resolve(import.meta.dir, '../modules/container-platform/main.tf'), 'utf8');
  expect(source).toMatch(/replace_triggered_by\s*=\s*\[azapi_resource\.subnet\.id\]/);
  expect(source).not.toMatch(/replace_triggered_by\s*=\s*\[azapi_resource\.subnet\]/);
});
