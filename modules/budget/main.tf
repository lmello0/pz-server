## --- Monthly cost budget with email alerts ---
# A safety net, not a spending cap: AWS does NOT stop anything when you
# cross the threshold, it just emails you. That's still the single most
# useful guardrail for a learning account, where the usual failure mode
# is leaving something running and not noticing for a month.
resource "aws_budgets_budget" "monthly" {
  name         = "${var.project_name}-monthly"
  budget_type  = "COST"
  limit_amount = var.monthly_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Fires when ACTUAL spend crosses 80% of the limit.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  # Fires when actual spend hits 100%.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  # FORECASTED is the genuinely useful one: it warns when AWS projects
  # you'll blow the budget by month end, based on current burn rate. That
  # gives you days of warning instead of finding out after the fact.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}
