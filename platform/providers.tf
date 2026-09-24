terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }

  subscription_id = var.subscription_id
}

# Workspace-level, not account-level: the host is this environment's own
# workspace_url, resolvable once the workspace exists (stage 1 of the
# two-stage bootstrap, see docs/IMPLEMENTATION.html, "Providers and
# authentication").
#
# auth_type comes from var.databricks_auth_type, null by default. A value set
# in this block always wins over the DATABRICKS_AUTH_TYPE environment variable,
# so leaving it null lets each context supply its own: locally export
# DATABRICKS_AUTH_TYPE=azure-cli; in CI, terraform.yml sets
# DATABRICKS_AUTH_TYPE=github-oidc, DATABRICKS_HOST and DATABRICKS_CLIENT_ID on
# the dev jobs (Databricks' own OAuth token federation, separate from
# azurerm's ARM_USE_OIDC). config/prod/values.tfvars pins "azure-cli" because no prod
# workflow supplies these variables yet.
#
# azure_tenant_id is only used by the azure-cli path and is ignored under
# github-oidc.
provider "databricks" {
  host            = module.databricks_workspace.workspace_url
  auth_type       = var.databricks_auth_type
  azure_tenant_id = var.azure_tenant_id
}
