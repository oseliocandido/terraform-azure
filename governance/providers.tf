terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.0"
    }
  }
}

# Workspace-level provider on this environment's workspace. The URL is an input
# (platform's workspace_url output) so this root does not read platform's state.
# auth_type is null by default so DATABRICKS_AUTH_TYPE decides, as in platform/.
provider "databricks" {
  host            = var.workspace_url
  auth_type       = var.databricks_auth_type
  azure_tenant_id = var.azure_tenant_id
}
