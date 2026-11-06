import assert from 'node:assert/strict';
import { resolve } from 'node:path';

// Independent expected values for the synthetic fixtures in callers' contract.tftest.hcl.
const subscription = '/subscriptions/11111111-1111-1111-1111-111111111111';
const principals = ['22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333'];
const role = `${subscription}/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe`;

export function checkCallerPlans(directory, stdout) {
  const match = directory === 'subscription-controls' ? ['', 'subscription-controls'] : directory === 'bootstrap/admin' ? ['', 'bootstrap', 'admin'] : /^(environments|bootstrap)\/(dev|qa|preprod|prod)$/.exec(directory);
  assert.ok(match, 'Select an existing environment or bootstrap caller');
  const [, kind, environment] = match;
  let events;
  try {
    events = stdout.trim().split('\n').filter(Boolean).map(line => JSON.parse(line));
  } catch {
    throw new Error('Terraform emitted malformed JSON');
  }
  assert.ok(events.some(event => event.type === 'test_summary' && event.test_summary.status === 'pass'), 'Terraform must report a passing test summary');

  function plan(run) {
    const belongs = event => event['@testfile'] === 'tests/contract.tftest.hcl' && event['@testrun'] === run;
    assert.ok(events.some(event => belongs(event) && event.type === 'test_run' && event.test_run.progress === 'complete' && event.test_run.status === 'pass'), `${run} must complete successfully`);
    const plans = events.filter(event => belongs(event) && event.type === 'test_plan');
    assert.equal(plans.length, 1, `${run} must emit exactly one plan`);
    return plans[0].test_plan;
  }
  function resource(plan, address) {
    const matches = (plan.resource_changes ?? []).filter(change => change.address === address);
    assert.equal(matches.length, 1, `Missing or duplicate planned resource: ${address}`);
    assert.ok(matches[0].change.after, `Missing planned values: ${address}`);
    return matches[0].change.after;
  }

  if (kind === 'subscription-controls') {
    assert.deepEqual(plan('budget_absent').resource_changes ?? [], [], 'Default must create no subscription controls');
    const enabled = plan('budget_contract');
    assert.deepEqual(enabled.resource_changes.map(change => change.address), ['azapi_resource.budget[0]'], 'Only one subscription budget is allowed');
    const budget = resource(enabled, 'azapi_resource.budget[0]');
    assert.equal(budget.parent_id, subscription, 'Budget subscription scope');
    assert.equal(budget.type, 'Microsoft.Consumption/budgets@2024-08-01', 'Budget API version');
    assert.ok(budget.location == null || budget.location === '', 'Subscription budget has no region');
    assert.deepEqual(budget.body, { properties: {
      amount: 300, category: 'Cost', timeGrain: 'Monthly',
      timePeriod: { startDate: '2026-11-01T00:00:00Z', endDate: '2027-11-01T00:00:00Z' },
      notifications: Object.fromEntries([['actual_50',50,'Actual'],['actual_80',80,'Actual'],['actual_100',100,'Actual'],['forecast_100',100,'Forecasted']].map(([key,threshold,thresholdType]) => [key, {
        enabled: true, operator: 'GreaterThanOrEqualTo', threshold, thresholdType,
        contactEmails: ['FinOps+alerts@example.com', 'operators@example.com'], contactGroups: [], contactRoles: [],
      }])),
    } }, 'Approved unfiltered budget and email-only notification contract');
    assert.deepEqual(enabled.output_changes.budget.after, { id: budget.id, name: 'pipesor-monthly' }, 'Budget exports identity only');
  } else if (kind === 'environments') {
    const baseline = plan(`${environment}_root_contract`);
    assert.ok(!(baseline.resource_changes ?? []).some(change => change.address.startsWith('module.foundry[')), 'Opt-out must plan no Foundry resources');
    assert.ok(!(baseline.resource_changes ?? []).some(change => change.address.startsWith('module.container_platform[')), 'Opt-out must plan no platform resources');
    assert.ok(!(baseline.resource_changes ?? []).some(change => change.address.startsWith('module.static_web_app[')), 'Opt-out must plan no static hosting');
    const enabled = plan('opt_in_platform_contract');
    const group = `${subscription}/resourceGroups/rg-pipesor-${environment}`;
    const rg = resource(enabled, 'module.resource_group.module.resource_group.azapi_resource.this');
    assert.equal(rg.parent_id, subscription, 'Resource group subscription');
    assert.equal(rg.location, 'testregion', 'Resource group metadata location');
    const prefix = 'module.container_platform[0].azapi_resource.';
    const network = resource(enabled, prefix + 'network');
    const subnet = resource(enabled, prefix + 'subnet');
    const workspace = resource(enabled, prefix + 'workspace');
    const platform = resource(enabled, prefix + 'environment');
    for (const item of [network, workspace, platform]) {
      assert.equal(item.parent_id, group, 'Caller resource group forwarding');
      assert.equal(item.location, 'workloadregion', 'Caller workload location forwarding');
    }
    assert.deepEqual(network.body.properties.addressSpace.addressPrefixes, ['10.50.0.0/16'], 'Caller VNet allocation');
    assert.equal(subnet.body.properties.addressPrefix, '10.50.1.0/24', 'Caller subnet allocation');
    assert.equal(subnet.parent_id, network.id, 'Subnet parent');
    assert.equal(platform.body.properties.vnetConfiguration.infrastructureSubnetId, subnet.id, 'Environment subnet');
    assert.equal(workspace.body.properties.retentionInDays, 45, 'Caller telemetry retention');
    assert.equal(workspace.body.properties.workspaceCapping.dailyQuotaGb, 0.5, 'Caller ingestion cap');
    const output = enabled.output_changes?.container_platform?.after;
    assert.ok(output, 'Missing platform output');
    for (const item of [network, subnet, workspace, platform]) assert.ok(item.id, 'Missing mocked resource ID');
    assert.deepEqual([output.environment_id, output.infrastructure_subnet_id, output.workspace_id, output.network_id], [platform.id, subnet.id, workspace.id, network.id], 'Caller resource ID exports');
    const webPlan = plan('opt_in_static_web_app_contract');
    assert.deepEqual(webPlan.resource_changes.filter(change => change.address.startsWith('module.static_web_app[')).map(change => change.address), ['module.static_web_app[0].azapi_resource.site'], 'Static hosting scope contains only one site');
    const web = resource(webPlan, 'module.static_web_app[0].azapi_resource.site');
    assert.equal(web.parent_id, group, 'Static hosting caller resource group');
    assert.equal(web.location, 'webregion', 'Static hosting caller region');
    assert.equal(web.name, `test-pipesor-${environment}-web`, 'Static hosting caller name');
    assert.equal(web.tags.environment, environment, 'Static hosting caller environment');
    assert.deepEqual(web.body, {
      sku: { name: 'Free', tier: 'Free' },
      properties: { publicNetworkAccess: 'Enabled', enterpriseGradeCdnStatus: 'Disabled', stagingEnvironmentPolicy: 'Disabled', buildProperties: { skipGithubActionWorkflowGeneration: true } },
    }, 'Static hosting must remain Free and detached from authentication and delivery');
    assert.deepEqual(webPlan.output_changes.static_web_app.after, { id: web.id, name: web.name, location: 'webregion', default_hostname: web.output.properties.defaultHostname }, 'Static hosting caller interface');
    const foundryPlan = plan('opt_in_foundry_contract');
    assert.deepEqual(foundryPlan.resource_changes.filter(change => change.address.startsWith('module.foundry[')).map(change => change.address).sort(), ['module.foundry[0].azapi_resource.account', 'module.foundry[0].azapi_resource.project'], 'Foundry scope contains only account and project');
    const account = resource(foundryPlan, 'module.foundry[0].azapi_resource.account');
    const project = resource(foundryPlan, 'module.foundry[0].azapi_resource.project');
    assert.equal(account.parent_id, group, 'Foundry caller resource group');
    assert.equal(account.location, 'airegion', 'Foundry caller region');
    assert.equal(account.name, `test-pipesor-${environment}-ai`, 'Foundry caller account name');
    assert.equal(account.tags.environment, environment, 'Foundry caller environment');
    assert.equal(project.name, `pipesor-${environment}`, 'Foundry caller project name');
    assert.equal(project.parent_id, account.id, 'Foundry caller project parenting');
    assert.equal(project.location, 'airegion', 'Foundry caller project region');
    assert.equal(account.body.properties.disableLocalAuth, true, 'Foundry caller Entra authentication');
    assert.equal(account.body.properties.publicNetworkAccess, 'Enabled', 'Foundry caller public endpoint');
    assert.deepEqual(foundryPlan.output_changes.foundry.after, {
      account_id: account.id, account_name: account.name, project_id: project.id,
      project_name: project.name, location: 'airegion', endpoint: account.output.properties.endpoint,
    }, 'Foundry caller interface');
    const telemetryPlan = plan('opt_in_application_insights_contract');
    const telemetry = resource(telemetryPlan, 'module.application_insights[0].azapi_resource.component');
    const telemetryWorkspace = resource(telemetryPlan, prefix + 'workspace');
    assert.equal(telemetry.parent_id, group, 'Telemetry caller resource group');
    assert.equal(telemetry.location, 'workloadregion', 'Telemetry caller location');
    assert.equal(telemetry.name, `appipipesor${environment}`, 'Telemetry caller environment');
    assert.equal(telemetry.body.properties.WorkspaceResourceId, telemetryWorkspace.id, 'Telemetry caller workspace forwarding');
    assert.equal(telemetry.body.properties.DisableLocalAuth, true, 'Telemetry caller Entra authentication');
    const databasePlan = plan('opt_in_postgresql_contract');
    const pgPrefix = 'module.postgresql[0].azapi_resource.';
    const databaseNetwork = resource(databasePlan, prefix + 'network');
    const pgSubnet = resource(databasePlan, pgPrefix + 'subnet');
    const server = resource(databasePlan, pgPrefix + 'server');
    const admin = resource(databasePlan, pgPrefix + 'administrator');
    assert.equal(server.parent_id, group, 'Database caller resource group');
    assert.equal(server.location, 'workloadregion', 'Database caller region');
    assert.equal(server.name, `test-pipesor-${environment}-pg`, 'Database caller name');
    assert.equal(pgSubnet.parent_id, databaseNetwork.id, 'Database caller VNet');
    assert.equal(pgSubnet.body.properties.addressPrefix, '10.50.2.0/28', 'Database caller allocation');
    assert.equal(admin.name, principals[0], 'Database caller administrator');
    assert.equal(server.body.properties.authConfig.tenantId, subscription.split('/')[2], 'Database caller tenant');
    const combined = plan('combined_foundations_contract');
    const approvedResources = new Set([
      'module.resource_group.module.resource_group.azapi_resource.this',
      ...['network', 'subnet', 'workspace', 'environment', 'logs'].map(name => prefix + name),
      ...['subnet', 'dns', 'dns_link', 'server', 'administrator'].map(name => pgPrefix + name),
      'module.postgresql[0].azapi_update_resource.extensions',
      'module.application_insights[0].azapi_resource.component',
      'module.service_bus[0].azapi_resource.namespace',
      'module.foundry[0].azapi_resource.account',
      'module.foundry[0].azapi_resource.project',
      'module.static_web_app[0].azapi_resource.site',
    ]);
    for (const change of combined.resource_changes ?? []) {
      // Resource-group AVM helpers remain owned by the pinned upstream module.
      const groupHelper = change.address.startsWith('module.resource_group.') && !change.type?.startsWith('azapi_');
      assert.ok(change.mode === 'data' || groupHelper || approvedResources.has(change.address), 'Combined scope contains only approved foundation resources');
    }
    const shared = resource(combined, prefix + 'network');
    const acaSubnet = resource(combined, prefix + 'subnet');
    const logs = resource(combined, prefix + 'workspace');
    const aca = resource(combined, prefix + 'environment');
    const database = resource(combined, pgPrefix + 'server');
    const databaseSubnet = resource(combined, pgPrefix + 'subnet');
    const dns = resource(combined, pgPrefix + 'dns');
    const dnsLink = resource(combined, pgPrefix + 'dns_link');
    const insights = resource(combined, 'module.application_insights[0].azapi_resource.component');
    const bus = resource(combined, 'module.service_bus[0].azapi_resource.namespace');
    const ai = resource(combined, 'module.foundry[0].azapi_resource.account');
    const aiProject = resource(combined, 'module.foundry[0].azapi_resource.project');
    const site = resource(combined, 'module.static_web_app[0].azapi_resource.site');
    for (const item of [shared, logs, aca, database, insights, bus, ai, site]) {
      assert.equal(item.parent_id, group, 'Combined foundation environment boundary');
      assert.ok(item.id?.startsWith(group + '/providers/'), 'Combined foundation resource identity');
    }
    for (const [item, location] of [[shared, 'workloadregion'], [logs, 'workloadregion'], [aca, 'workloadregion'], [database, 'workloadregion'], [insights, 'workloadregion'], [bus, 'messagingregion'], [ai, 'airegion'], [aiProject, 'airegion'], [site, 'webregion']]) {
      assert.equal(item.location, location, 'Combined explicit region forwarding');
    }
    assert.equal(databaseSubnet.parent_id, shared.id, 'Combined database VNet');
    assert.equal(acaSubnet.parent_id, shared.id, 'Combined ACA VNet');
    assert.notEqual(acaSubnet.id, databaseSubnet.id, 'Combined subnets must stay distinct');
    assert.equal(aca.body.properties.vnetConfiguration.infrastructureSubnetId, acaSubnet.id, 'Combined ACA subnet binding');
    assert.deepEqual(database.body.properties.network, { delegatedSubnetResourceId: databaseSubnet.id, privateDnsZoneArmResourceId: dns.id }, 'Combined database private connectivity');
    assert.equal(dnsLink.parent_id, dns.id, 'Combined DNS zone parenting');
    assert.equal(dnsLink.body.properties.virtualNetwork.id, shared.id, 'Combined private DNS VNet');
    assert.equal(insights.body.properties.WorkspaceResourceId, logs.id, 'Combined telemetry workspace');
    assert.equal(resource(combined, prefix + 'logs').body.properties.workspaceId, logs.id, 'Combined ACA logs workspace');
    assert.equal(aiProject.parent_id, ai.id, 'Combined Foundry project parenting');
    assert.deepEqual([logs.body.properties.features.disableLocalAuth, insights.body.properties.DisableLocalAuth, bus.body.properties.disableLocalAuth, ai.body.properties.disableLocalAuth], [true, true, true, true], 'Combined Entra-only security');
    assert.equal(database.body.properties.authConfig.passwordAuth, 'Disabled', 'Combined database password security');
    assert.deepEqual(site.body, web.body, 'Combined static hosting security');
    for (const [key, expected] of Object.entries({ container_platform: { network_id: shared.id, infrastructure_subnet_id: acaSubnet.id, workspace_id: logs.id, environment_id: aca.id }, postgresql: { id: database.id, subnet_id: databaseSubnet.id, private_dns_zone_id: dns.id }, application_insights: { id: insights.id, workspace_id: logs.id }, service_bus: { id: bus.id }, foundry: { account_id: ai.id, project_id: aiProject.id }, static_web_app: { id: site.id } })) {
      for (const [field, value] of Object.entries(expected)) assert.equal(combined.output_changes?.[key]?.after?.[field], value, 'Combined output wiring');
    }
  } else {
    const configured = plan(`${environment}_bootstrap_isolation`);
    const group = `${subscription}/resourceGroups/rg-pipesor-state-${environment}`;
    const prefix = 'module.state_store.module.';
    const rg = resource(configured, prefix + 'resource_group.azapi_resource.this');
    const storage = resource(configured, prefix + 'storage.azapi_resource.this');
    const recovery = resource(configured, prefix + 'blob_service.azapi_update_resource.this');
    const container = resource(configured, prefix + 'container.azapi_resource.this');
    assert.equal(rg.parent_id, subscription, 'State resource group subscription');
    assert.equal(rg.location, 'testregion', 'State metadata location');
    assert.equal(storage.parent_id, group, 'State account resource group');
    assert.equal(storage.location, 'testregion', 'Caller storage location');
    assert.equal(storage.name, environment === 'preprod' ? 'pipesorstatepreprod' : `pipesorstatefixture${environment}`, 'Caller account name');
    assert.equal(storage.body.sku.name, environment === 'admin' ? 'Standard_LRS' : 'Standard_ZRS', 'Caller replication');
    assert.deepEqual(storage.body.properties.networkAcls.ipRules.map(rule => rule.value).sort(), ['198.51.100.5', '203.0.113.0/24'], 'Caller operator allowlist');
    for (const policy of ['deleteRetentionPolicy', 'containerDeleteRetentionPolicy']) {
      assert.equal(recovery.body.properties[policy].days, environment === 'admin' ? 30 : 17, 'Caller recovery window');
    }
    assert.ok(container.id, 'Missing mocked container ID');
    const grants = (configured.resource_changes ?? []).filter(change => change.type === 'azapi_resource' && change.change.after?.type?.startsWith('Microsoft.Authorization/roleAssignments@')).map(change => change.change.after);
    assert.deepEqual(grants.map(grant => [grant.body.properties.principalId, grant.parent_id, grant.body.properties.roleDefinitionId]).sort(), principals.map(principal => [principal, container.id, role]).sort(), 'Caller principals, container scope and role');
  }
}

if (import.meta.main) {
  const directory = process.argv[2];
  const module = /^modules\/(resource-group|state-store|container-platform|service-bus|postgresql|application-insights|foundry|static-web-app)$/.test(directory);
  assert.ok(module || directory === 'subscription-controls' || directory === 'bootstrap/admin' || /^(environments|bootstrap)\/(dev|qa|preprod|prod)$/.test(directory), 'Select one reviewed Terraform directory');
  const command = ['terraform', `-chdir=${directory}`, 'test', '-filter=tests/contract.tftest.hcl'];
  if (!module) command.push('-json', '-verbose');
  const result = Bun.spawnSync(command, { cwd: resolve(import.meta.dir, '..'), stdout: 'pipe', stderr: 'pipe' });
  const stdout = result.stdout.toString();
  if (module) process.stdout.write(stdout);
  if (result.exitCode !== 0) {
    console.error(`${directory}: terraform test failed (${result.exitCode})`);
    if (!module) {
      for (const line of stdout.trim().split('\n').filter(Boolean)) {
        try {
          const event = JSON.parse(line);
          if (event.type === 'diagnostic') console.error(event.diagnostic.summary, event.diagnostic.detail);
        } catch { console.error('Terraform emitted malformed JSON'); }
      }
    }
    process.stderr.write(result.stderr);
    process.exit(result.exitCode || 1);
  }
  if (!module) {
    checkCallerPlans(directory, stdout);
    console.log(`${directory}: native tests and caller resource contracts passed`);
  }
}
