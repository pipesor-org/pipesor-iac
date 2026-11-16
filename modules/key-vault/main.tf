locals {
  vaults               = merge({ app_material = var.configuration.app_material_name }, var.configuration.custody == null ? {} : { custody = var.configuration.custody.name })
  custody_principals   = var.configuration.custody == null ? {} : var.configuration.custody.principals
  custody_role_id      = "/subscriptions/${split("/", var.resource_group_id)[2]}/providers/Microsoft.Authorization/roleDefinitions/${uuidv5("url", "${lower(var.resource_group_id)}/pipesor-${var.environment}-credential-custody")}"
  secrets_user_role_id = "/subscriptions/${split("/", var.resource_group_id)[2]}/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6"
}

resource "azapi_resource" "vault" {
  for_each  = local.vaults
  type      = "Microsoft.KeyVault/vaults@2024-11-01"
  name      = each.value
  parent_id = var.resource_group_id
  location  = var.configuration.location
  tags      = { environment = var.environment, purpose = each.key }
  body = {
    properties = {
      tenantId                     = var.configuration.tenant_id
      sku                          = { family = "A", name = "standard" }
      accessPolicies               = []
      enableRbacAuthorization      = true
      enableSoftDelete             = true
      enablePurgeProtection        = true
      softDeleteRetentionInDays    = 30
      enabledForDeployment         = false
      enabledForDiskEncryption     = false
      enabledForTemplateDeployment = false
      publicNetworkAccess          = "Enabled"
      networkAcls = {
        bypass              = "None"
        defaultAction       = "Deny"
        ipRules             = [for ip in sort(tolist(var.configuration.allowed_public_ipv4s)) : { value = ip }]
        virtualNetworkRules = [for id in sort(tolist(var.allowed_subnet_ids)) : { id = id, ignoreMissingVnetServiceEndpoint = false }]
      }
    }
  }
  response_export_values           = ["properties.vaultUri"]
  replace_triggers_external_values = [var.configuration.location, var.configuration.tenant_id]
}

resource "azapi_resource" "app_material_reader" {
  for_each  = var.configuration.app_material_readers
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = uuidv5("url", "${lower(azapi_resource.vault["app_material"].id)}/${lower(each.value.object_id)}/${local.secrets_user_role_id}")
  parent_id = azapi_resource.vault["app_material"].id
  body = { properties = {
    principalId      = lower(each.value.object_id)
    principalType    = each.value.principal_type
    roleDefinitionId = local.secrets_user_role_id
  } }
  response_export_values = []
}

resource "azapi_resource" "custody_role" {
  count     = length(local.custody_principals) == 0 ? 0 : 1
  type      = "Microsoft.Authorization/roleDefinitions@2022-04-01"
  name      = basename(local.custody_role_id)
  parent_id = "/subscriptions/${split("/", var.resource_group_id)[2]}"
  body = { properties = {
    roleName         = "pipesor-${var.environment}-${var.configuration.custody.name}-credential-custody"
    description      = "Read exact credential versions and create versions; no list, delete, recovery, purge or access administration."
    type             = "CustomRole"
    assignableScopes = [var.resource_group_id]
    permissions = [{
      actions     = [], notActions = [], notDataActions = []
      dataActions = ["Microsoft.KeyVault/vaults/secrets/getSecret/action", "Microsoft.KeyVault/vaults/secrets/setSecret/action"]
    }]
  } }
  response_export_values = []
}

resource "azapi_resource" "custody_writer" {
  for_each  = local.custody_principals
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = uuidv5("url", "${lower(azapi_resource.vault["custody"].id)}/${lower(each.value.object_id)}/${lower(local.custody_role_id)}")
  parent_id = azapi_resource.vault["custody"].id
  body = { properties = {
    principalId      = lower(each.value.object_id)
    principalType    = each.value.principal_type
    roleDefinitionId = azapi_resource.custody_role[0].id
  } }
  response_export_values = []
}
