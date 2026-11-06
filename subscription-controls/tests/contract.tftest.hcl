mock_provider "azapi" {}
variables {
  subscription_id = "11111111-1111-1111-1111-111111111111"
}
run "budget_absent" {
  command = plan
  assert {
    condition     = length(azapi_resource.budget) == 0 && output.budget == null
    error_message = "The default must create no subscription controls."
  }
}
run "budget_contract" {
  command = plan
  variables {
    budget = {
      name           = "pipesor-monthly"
      start_date     = "2026-11-01"
      end_date       = "2027-11-01"
      contact_emails = ["FinOps+alerts@example.com", "operators@example.com"]
    }
  }
  override_resource {
    target          = azapi_resource.budget[0]
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.Consumption/budgets/pipesor-monthly", location = "" }
  }
  assert {
    condition     = azapi_resource.budget[0].parent_id == "/subscriptions/11111111-1111-1111-1111-111111111111" && azapi_resource.budget[0].location == ""
    error_message = "Budget belongs to the subscription, not an environment resource group or region."
  }
  assert {
    condition     = azapi_resource.budget[0].body.properties.amount == 300 && azapi_resource.budget[0].body.properties.category == "Cost" && azapi_resource.budget[0].body.properties.timeGrain == "Monthly" && length(keys(azapi_resource.budget[0].body.properties)) == 5
    error_message = "Track an unfiltered calendar-month 300 cost budget without filters or other controls."
  }
  assert {
    condition     = azapi_resource.budget[0].body.properties.timePeriod == { startDate = "2026-11-01T00:00:00Z", endDate = "2027-11-01T00:00:00Z" } && length(azapi_resource.budget[0].body.properties.notifications) == 4
    error_message = "Preserve explicit dates and exactly four approved notifications."
  }
  assert {
    condition     = alltrue([for key, value in azapi_resource.budget[0].body.properties.notifications : value.enabled && value.operator == "GreaterThanOrEqualTo" && value.threshold == lookup({ actual_50 = 50, actual_80 = 80, actual_100 = 100, forecast_100 = 100 }, key) && value.thresholdType == (key == "forecast_100" ? "Forecasted" : "Actual") && value.contactEmails == tolist(["FinOps+alerts@example.com", "operators@example.com"]) && length(value.contactGroups) == 0 && length(value.contactRoles) == 0])
    error_message = "Use Actual 50/80/100 and Forecasted 100 email notifications, without action groups or implicit role recipients."
  }
  assert {
    condition     = output.budget.name == "pipesor-monthly" && output.budget.id == azapi_resource.budget[0].id && length(keys(output.budget)) == 2 && length(azapi_resource.budget[0].response_export_values) == 0
    error_message = "Export budget identity only."
  }
}
run "reject_name_null" {
  command = plan
  variables { budget = { name = null
    start_date = "2026-11-01"
    end_date   = "2027-11-01"
  contact_emails = ["operators@example.com"] } }
  expect_failures = [var.budget]
}
run "reject_name_invalid" {
  command = plan
  variables { budget = { name = "bad/name"
    start_date = "2026-11-01"
    end_date   = "2027-11-01"
  contact_emails = ["operators@example.com"] } }
  expect_failures = [var.budget]
}
run "reject_start_null" {
  command = plan
  variables { budget = { name = "pipesor-monthly"
    start_date = null
    end_date   = "2027-11-01"
  contact_emails = ["operators@example.com"] } }
  expect_failures = [var.budget]
}
run "reject_start_not_first" {
  command = plan
  variables { budget = { name = "pipesor-monthly"
    start_date = "2026-11-02"
    end_date   = "2027-11-01"
  contact_emails = ["operators@example.com"] } }
  expect_failures = [var.budget]
}
run "reject_start_invalid" {
  command = plan
  variables { budget = { name = "pipesor-monthly"
    start_date = "2026-13-01"
    end_date   = "2027-11-01"
  contact_emails = ["operators@example.com"] } }
  expect_failures = [var.budget]
}
run "reject_end_invalid" {
  command = plan
  variables { budget = { name = "pipesor-monthly"
    start_date = "2026-11-01"
    end_date   = "2027-02-30"
  contact_emails = ["operators@example.com"] } }
  expect_failures = [var.budget]
}
run "reject_end_null" {
  command = plan
  variables { budget = { name = "pipesor-monthly"
    start_date = "2026-11-01"
    end_date   = null
  contact_emails = ["operators@example.com"] } }
  expect_failures = [var.budget]
}
run "reject_end_before" {
  command = plan
  variables { budget = { name = "pipesor-monthly"
    start_date = "2026-11-01"
    end_date   = "2026-10-01"
  contact_emails = ["operators@example.com"] } }
  expect_failures = [var.budget]
}
run "reject_end_equal" {
  command = plan
  variables { budget = { name = "pipesor-monthly"
    start_date = "2026-11-01"
    end_date   = "2026-11-01"
  contact_emails = ["operators@example.com"] } }
  expect_failures = [var.budget]
}
run "reject_emails_empty" {
  command = plan
  variables { budget = { name = "pipesor-monthly"
    start_date = "2026-11-01"
    end_date   = "2027-11-01"
  contact_emails = [] } }
  expect_failures = [var.budget]
}
run "reject_emails_null" {
  command = plan
  variables { budget = { name = "pipesor-monthly"
    start_date = "2026-11-01"
    end_date   = "2027-11-01"
  contact_emails = null } }
  expect_failures = [var.budget]
}
run "reject_email_invalid" {
  command = plan
  variables { budget = { name = "pipesor-monthly"
    start_date = "2026-11-01"
    end_date   = "2027-11-01"
  contact_emails = ["bad-address"] } }
  expect_failures = [var.budget]
}
run "reject_email_null" {
  command = plan
  variables { budget = { name = "pipesor-monthly"
    start_date = "2026-11-01"
    end_date   = "2027-11-01"
  contact_emails = [null] } }
  expect_failures = [var.budget]
}
run "reject_email_whitespace" {
  command = plan
  variables { budget = { name = "pipesor-monthly"
    start_date = "2026-11-01"
    end_date   = "2027-11-01"
  contact_emails = [" bad@example.com"] } }
  expect_failures = [var.budget]
}
run "reject_emails_too_many" {
  command = plan
  variables { budget = { name = "pipesor-monthly"
    start_date = "2026-11-01"
    end_date   = "2027-11-01"
  contact_emails = ["a@example.com", "b@example.com", "c@example.com", "d@example.com", "e@example.com", "f@example.com"] } }
  expect_failures = [var.budget]
}
run "reject_subscription" {
  command = plan
  variables { subscription_id = "not-a-uuid" }
  expect_failures = [var.subscription_id]
}
