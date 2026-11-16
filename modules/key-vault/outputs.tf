output "vaults" {
  description = "Environment-owned vault identities/endpoints only; no secret names, versions or payloads."
  value = { for purpose, vault in azapi_resource.vault : purpose => {
    id        = vault.id
    name      = vault.name
    location  = vault.location
    tenant_id = var.configuration.tenant_id
    uri       = vault.output.properties.vaultUri
  } }
}
