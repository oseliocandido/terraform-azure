variable "notify_email" {
  type        = string
  description = "Email address to receive budget threshold alerts."
}

variable "monthly_amount" {
  type        = number
  default     = 20
  description = "Monthly budget cap in the subscription's billing currency."
}

resource "azurerm_consumption_budget_subscription" "learning_guard" {
  name            = "guard-learning-subscription"
  subscription_id = "/subscriptions/${var.subscription_id}"

  amount     = var.monthly_amount
  time_grain = "Monthly"

  time_period {
    start_date = "${formatdate("YYYY-MM-01", timestamp())}T00:00:00Z"
    # Consumption budgets require an end date; five years out is effectively
    # "no end" without hitting API limits some regions enforce on far-future dates.
    end_date = "${formatdate("YYYY-MM-01", timeadd(timestamp(), "43800h"))}T00:00:00Z"
  }

  notification {
    enabled        = true
    threshold      = 50
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = [var.notify_email]
  }

  notification {
    enabled        = true
    threshold      = 90
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = [var.notify_email]
  }

  lifecycle {
    # timestamp()/timeadd() change on every plan by nature - ignore drift on
    # the dates so this doesn't show a spurious diff on every subsequent plan.
    ignore_changes = [time_period]
  }
}

output "budget_id" {
  value = azurerm_consumption_budget_subscription.learning_guard.id
}
