import assert from 'node:assert/strict';
import { resolve } from 'node:path';

// Independent expected values for the synthetic fixtures in callers' contract.tftest.hcl.
const subscription = '/subscriptions/11111111-1111-1111-1111-111111111111';
const principals = ['22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333'];
const role = `${subscription}/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe`;

export function checkCallerPlans(directory, stdout) {
  const match = /^(environments|bootstrap)\/(dev|qa|preprod|prod)$/.exec(directory);
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

  if (kind === 'environments') {
    const baseline = plan(`${environment}_root_contract`);
    assert.ok(!(baseline.resource_changes ?? []).some(change => change.address.startsWith('module.container_platform[')), 'Opt-out must plan no platform resources');
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
    assert.equal(storage.body.sku.name, 'Standard_ZRS', 'Caller replication');
    assert.deepEqual(storage.body.properties.networkAcls.ipRules.map(rule => rule.value).sort(), ['198.51.100.5', '203.0.113.0/24'], 'Caller operator allowlist');
    for (const policy of ['deleteRetentionPolicy', 'containerDeleteRetentionPolicy']) {
      assert.equal(recovery.body.properties[policy].days, 17, 'Caller recovery window');
    }
    assert.ok(container.id, 'Missing mocked container ID');
    const grants = (configured.resource_changes ?? []).filter(change => change.type === 'azapi_resource' && change.change.after?.type?.startsWith('Microsoft.Authorization/roleAssignments@')).map(change => change.change.after);
    assert.deepEqual(grants.map(grant => [grant.body.properties.principalId, grant.parent_id, grant.body.properties.roleDefinitionId]).sort(), principals.map(principal => [principal, container.id, role]).sort(), 'Caller principals, container scope and role');
  }
}

if (import.meta.main) {
  const directory = process.argv[2];
  const module = /^modules\/(resource-group|state-store|container-platform|service-bus)$/.test(directory);
  assert.ok(module || /^(environments|bootstrap)\/(dev|qa|preprod|prod)$/.test(directory), 'Select one reviewed Terraform directory');
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
