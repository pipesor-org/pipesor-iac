variable "environment" {
  description = "Pipesor environment; each caller has its own root and remote state."
  type        = string
  nullable    = false

  validation {
    condition     = contains(["dev", "qa", "preprod", "prod"], var.environment)
    error_message = "Environment must be dev, qa, preprod or prod."
  }
}

variable "location" {
  description = "Explicit Azure region code for resource-group metadata; no workload region is selected here."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9]+$", var.location))
    error_message = "Location must be a nonempty lowercase Azure region code without whitespace."
  }
}
