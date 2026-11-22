output "namespace" {
  description = "Nonsecret namespace identity for later approved messaging entities and access grants; no credentials."
  value = {
    id       = azapi_resource.namespace.id
    name     = azapi_resource.namespace.name
    location = azapi_resource.namespace.location
  }
}

output "topology" {
  description = "Topic and subscription IDs for scoped data-plane role assignments; null without a topology."
  value = var.configuration.topology == null ? null : {
    topic_id         = azapi_resource.topic[0].id
    topic_name       = azapi_resource.topic[0].name
    subscription_ids = { for name, subscription in azapi_resource.subscription : name => subscription.id }
  }
}
