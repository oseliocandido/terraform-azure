# Dev values, applied on top of common.tfvars:
#   terraform plan -var-file=../config/common.tfvars -var-file=../config/dev/values.tfvars

environment   = "dev"
budget_amount = 20
instance      = 1

# Dev switches (see platform/variables.tf).
enable_compute            = true
bronze_consumer_can_write = true
workspace_user_domains    = ["sales", "marketing"]

# sp-terraform-dev's client ID (grants identify an Azure SP by it).
ci_service_principal_name = "5e93b219-9bc5-4a7b-8956-40d6c3648c1d"

# Grants to the domain groups, which exist in the account (docs/BACKLOG.md).
enable_grants = true

# Engineers keep MODIFY on all domain tables in dev. Prod leaves it off until a
# pipeline service principal owns production writes.
engineers_can_modify = true

# Governance building blocks (platform/governance.tf). Tag policies are
# account-wide, so only dev manages them. Audit access stays off until an admin
# can apply it.
enable_predictive_optimization = "ENABLE"
enable_tags                    = true
manage_account_tag_policies    = true
enable_audit_access            = false

# Stage 2 and 3 (governance-bundle/, governance/) need the security schema.
enable_security_schema = true

# governance/ policies: off until the functions exist (governance-bundle) and
# columns are tagged.
enable_mask_policy       = false
enable_row_filter_policy = false
