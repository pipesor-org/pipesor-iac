import { expect, test } from 'bun:test';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dir, '..');
const environments = ['dev', 'qa', 'preprod', 'prod'];

for (const environment of environments) {
  test(`${environment} exposes the approved nullable RAG runtime handoff`, () => {
    const directory = resolve(root, 'environments', environment);
    const variables = readFileSync(resolve(directory, 'variables.tf'), 'utf8');
    const outputs = readFileSync(resolve(directory, 'outputs.tf'), 'utf8');
    const example = readFileSync(resolve(directory, 'terraform.tfvars.example'), 'utf8');

    expect(variables).toContain('variable "rag_runtime_contract"');
    expect(variables).toContain('default = null');
    expect(variables).toContain('var.container_platform != null && var.foundry != null && var.postgresql != null');
    expect(variables).toContain('var.rag_runtime_contract.tenant_id == var.postgresql.tenant_id');
    expect(variables).toContain('Recommendation, RAG runtime, importer and migrator principals must be distinct.');
    expect(variables).not.toMatch(/rag_runtime_contract == null \|\| (?:alltrue|can|length)/);
    expect(outputs).toMatch(/model\s*= "text-embedding-3-small"/);
    expect(outputs).toMatch(/dimensions\s*= 1536/);
    expect(outputs).toMatch(/api\s*= "v1"/);
    expect(outputs).toMatch(/rag_type\s*= "SystemAssigned"/);
    expect(outputs).toMatch(/azure_openai_role_name\s*= "Cognitive Services OpenAI User"/);
    expect(outputs).toMatch(/app_role_name\s*= "Rag.Query"/);
    expect(outputs).toMatch(/runtime_access\s*= "knowledge_read"/);
    expect(outputs).toMatch(/import_access\s*= "knowledge_read_write"/);
    expect(outputs).toMatch(/migration_access\s*= "knowledge_ddl"/);
    expect(example).toContain(`#   embedding_deployment_name    = "pipesor-${environment}-embeddings"`);
  });
}

test('RAG handoff adds no Azure, Entra or PostgreSQL resources', () => {
  const changedContract = environments
    .flatMap(environment => ['variables.tf', 'outputs.tf'].map(file => readFileSync(resolve(root, 'environments', environment, file), 'utf8')))
    .join('\n');

  expect(changedContract).not.toMatch(/resource\s+"(?:azurerm|azuread|postgresql)_/);
});
