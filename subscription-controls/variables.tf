variable "subscription_id" {
  description = "Explicit target subscription UUID; independently verify offer, billing currency and scope before any future deployment."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("(?i)^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "Supply the target subscription UUID."
  }
}

variable "budget" {
  description = "Deferred subscription-wide monthly cost notification control. An enabled budget requires an approved amount; no operational threshold is selected. Dates are explicit YYYY-MM-DD; recipients must be approved durable operator addresses. Null creates no budget."
  type = object({
    # Omission becomes null so the same validation rejects missing and null amounts.
    amount         = optional(number)
    name           = string
    start_date     = string
    end_date       = string
    contact_emails = set(string)
  })
  default = null
  validation {
    condition     = var.budget == null ? true : try(var.budget.amount > 0 && can(jsonencode(var.budget.amount)), false)
    error_message = "An enabled budget requires an explicit positive finite amount in the verified subscription billing currency."
  }
  validation {
    condition     = var.budget == null ? true : can(regex("^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,62}$", var.budget.name))
    error_message = "Budget name must be 1-63 letters, digits, underscores, dots or hyphens, starting with a letter or digit."
  }
  validation {
    condition = var.budget == null ? true : try(
      can(regex("^[0-9]{4}-[0-9]{2}-01$", var.budget.start_date)) &&
      can(regex("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", var.budget.end_date)) &&
      timecmp("${var.budget.start_date}T00:00:00Z", "2017-06-01T00:00:00Z") >= 0 &&
      timecmp("${var.budget.end_date}T00:00:00Z", "${var.budget.start_date}T00:00:00Z") > 0,
    false)
    error_message = "Supply valid YYYY-MM-DD dates: start on a month's first day on/after 2017-06-01, with end after start. Azure's deployment-time start-date window must also be reviewed."
  }
  validation {
    condition = var.budget == null ? true : try(
      length(var.budget.contact_emails) >= 1 && length(var.budget.contact_emails) <= 5 &&
      alltrue([for email in var.budget.contact_emails : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", email))]),
    false)
    error_message = "Provide 1-5 approved email addresses without whitespace; use durable operator-owned recipients."
  }
}
