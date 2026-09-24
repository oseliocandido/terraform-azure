resource "azurerm_consumption_budget_resource_group" "learning_guard" {
  name              = "guard-learning-${var.environment}"
  resource_group_id = var.resource_group_id

  amount     = var.budget_amount
  time_grain = "Monthly"

  time_period {
    start_date = "${formatdate("YYYY-MM-01", timestamp())}T00:00:00Z"
    # An end date is required; five years out is effectively none.
    end_date = "${formatdate("YYYY-MM-01", timeadd(timestamp(), "43800h"))}T00:00:00Z"
  }

  notification {
    enabled        = true
    threshold      = 20
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = [var.notify_email]
  }

  notification {
    enabled        = true
    threshold      = 40
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = [var.notify_email]
  }

  lifecycle {
    # The dates come from timestamp(), which differs on every plan.
    ignore_changes = [time_period]
  }
}
