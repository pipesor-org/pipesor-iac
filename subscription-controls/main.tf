resource "azapi_resource" "budget" {
  count     = var.budget == null ? 0 : 1
  type      = "Microsoft.Consumption/budgets@2024-08-01"
  name      = var.budget.name
  parent_id = "/subscriptions/${var.subscription_id}"
  body = {
    properties = {
      amount    = var.budget.amount
      category  = "Cost"
      timeGrain = "Monthly"
      timePeriod = {
        startDate = "${var.budget.start_date}T00:00:00Z"
        endDate   = "${var.budget.end_date}T00:00:00Z"
      }
      notifications = {
        for key, settings in {
          actual_50    = { threshold = 50, type = "Actual" }
          actual_80    = { threshold = 80, type = "Actual" }
          actual_100   = { threshold = 100, type = "Actual" }
          forecast_100 = { threshold = 100, type = "Forecasted" }
          } : key => {
          enabled       = true
          operator      = "GreaterThanOrEqualTo"
          threshold     = settings.threshold
          thresholdType = settings.type
          contactEmails = sort(tolist(var.budget.contact_emails))
          contactGroups = []
          contactRoles  = []
        }
      }
    }
  }
  response_export_values = []
}
