variable "environment" {
  description = "Fixed environment identity; the namespace is shared only within this environment."
  type        = string
  nullable    = false
  validation {
    condition     = contains(["dev", "qa", "preprod", "prod"], var.environment)
    error_message = "Environment must be dev, qa, preprod or prod."
  }
}
variable "resource_group_id" {
  description = "Resource-group ARM ID owned by the isolated environment root."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("(?i)^/subscriptions/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/resourceGroups/[^/]+$", var.resource_group_id))
    error_message = "Supply a resource-group ARM ID with a subscription UUID."
  }
}
variable "configuration" {
  description = "Explicit globally available namespace name and approved workload location; no deployment values are defaulted."
  type = object({
    namespace_name = string
    location       = string
    topology = optional(object({
      topic_name                 = string
      message_ttl                = string
      duplicate_detection_window = string
      subscriptions = map(object({
        sql_filter         = string
        lock_duration      = string
        max_delivery_count = number
      }))
    }))
  })
  nullable = false
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,48}[a-z0-9]$", var.configuration.namespace_name))
    error_message = "Namespace name must be 6-50 lowercase letters, digits or hyphens, start with a letter and end with a letter or digit; verify global availability separately."
  }
  validation {
    condition     = can(regex("^[a-z][a-z0-9]+$", var.configuration.location))
    error_message = "Location must be an explicit lowercase Azure region code."
  }
  validation {
    condition = var.configuration.topology == null ? true : (
      can(regex("^[a-z][a-z0-9-]{0,49}$", var.configuration.topology.topic_name)) &&
      length(var.configuration.topology.subscriptions) > 0 &&
      alltrue([for name, subscription in var.configuration.topology.subscriptions :
        can(regex("^[a-z][a-z0-9-]{0,49}$", name)) && length(trimspace(subscription.sql_filter)) > 0 &&
        subscription.max_delivery_count >= 1 && subscription.max_delivery_count <= 100 &&
        can(regex("^PT([1-4]M|[1-5]?[0-9]S|5M)$", subscription.lock_duration))
      ]) && can(regex("^P", var.configuration.topology.message_ttl)) &&
      can(regex("^PT([1-9]|10)M$|^PT[2-9][0-9]S$", var.configuration.topology.duplicate_detection_window))
    )
    error_message = "Topology needs a topic, at least one subscription with a SQL filter, 1-100 deliveries, a lock of at most 5 minutes, an ISO-8601 TTL and a duplicate-detection window of 20 s to 10 minutes."
  }
}
