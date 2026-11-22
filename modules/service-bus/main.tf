resource "azapi_resource" "namespace" {
  type      = "Microsoft.ServiceBus/namespaces@2024-01-01"
  name      = var.configuration.namespace_name
  parent_id = var.resource_group_id
  location  = var.configuration.location
  tags      = { environment = var.environment }

  body = {
    sku = {
      name = "Standard"
      tier = "Standard"
    }
    properties = {
      disableLocalAuth    = true
      publicNetworkAccess = "Enabled"
      minimumTlsVersion   = "1.2"
    }
  }
}

# Runtime manifest messaging topology: one topic, one filtered subscription per consumer workload.
resource "azapi_resource" "topic" {
  count     = var.configuration.topology == null ? 0 : 1
  type      = "Microsoft.ServiceBus/namespaces/topics@2024-01-01"
  name      = var.configuration.topology.topic_name
  parent_id = azapi_resource.namespace.id
  body = { properties = {
    defaultMessageTimeToLive            = var.configuration.topology.message_ttl
    requiresDuplicateDetection          = true
    duplicateDetectionHistoryTimeWindow = var.configuration.topology.duplicate_detection_window
    enablePartitioning                  = false
    supportOrdering                     = false
  } }
}

resource "azapi_resource" "subscription" {
  for_each  = var.configuration.topology == null ? {} : var.configuration.topology.subscriptions
  type      = "Microsoft.ServiceBus/namespaces/topics/subscriptions@2024-01-01"
  name      = each.key
  parent_id = azapi_resource.topic[0].id
  body = { properties = {
    lockDuration                     = each.value.lock_duration
    maxDeliveryCount                 = each.value.max_delivery_count
    defaultMessageTimeToLive         = var.configuration.topology.message_ttl
    deadLetteringOnMessageExpiration = true
    requiresSession                  = false
  } }
}

# Subscriptions created through ARM have no rules (no implicit "$Default" match-all) and receive nothing until a
# rule exists; this single SQL rule selects the subscription's event type, as in the local emulator topology.
resource "azapi_resource" "filter" {
  for_each  = azapi_resource.subscription
  type      = "Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2024-01-01"
  name      = "event-type"
  parent_id = each.value.id
  body = { properties = {
    filterType = "SqlFilter"
    sqlFilter  = { sqlExpression = var.configuration.topology.subscriptions[each.key].sql_filter }
  } }
}
