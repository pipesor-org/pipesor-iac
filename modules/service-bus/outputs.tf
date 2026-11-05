output "namespace" {
  description = "Nonsecret namespace identity for later approved messaging entities and access grants; no credentials."
  value = {
    id       = azapi_resource.namespace.id
    name     = azapi_resource.namespace.name
    location = azapi_resource.namespace.location
  }
}
