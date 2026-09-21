#!/usr/bin/env bash
# Every command run to set up dev/prod isolation for this project: one Azure
# subscription (Free Trial plan blocked creating a second one), two resource
# groups, one remote Terraform state backend, and two OIDC-based CI identities
# (sp-terraform-dev / sp-terraform-prod), each scoped to only its own RG.
#
# This is a RECORD of what was already run, not meant to be re-run blindly --
# most steps are one-time and will error (harmlessly) if the resource already
# exists. Real IDs from this setup are left in below for reference.
#
# On Windows Git Bash, MSYS_NO_PATHCONV=1 is required before any command with
# a leading "/subscriptions/..." scope, or Git Bash silently mangles it into
# a Windows path and the Azure CLI call fails with a confusing error.

set -e

SUB=d12d5f8a-c771-485e-b633-c0c4f19c78e2   # "Azure subscription 1"
TENANT=b49702e3-2804-4841-be78-537ce48521dc
SA_NAME=sttfstate79820                      # backend storage account, globally-unique name

# ---------------------------------------------------------------------------
# 0. Investigate: could we get a second (prod) subscription?
# ---------------------------------------------------------------------------
az account list -o table
az billing account list -o table
az billing profile list --account-name "3a104626-eda0-5ebe-d5f1-b89c2f695ab4:0d98458f-e4e2-41e3-9ad3-8273661456f3_2019-05-31" -o table
az billing invoice section list \
  --account-name "3a104626-eda0-5ebe-d5f1-b89c2f695ab4:0d98458f-e4e2-41e3-9ad3-8273661456f3_2019-05-31" \
  --profile-name "TGG6-335H-BG7-PGB" -o table

az extension add --name account --yes

# This failed with (NotAllowed) AccountNeedsUpgrade -- Free Trial accounts
# can't create additional subscriptions via CLI/API. Fell back to a
# single-subscription design (RG-level isolation instead of subscription-level).
az account alias create \
  --name "prod-subscription-alias" \
  --billing-scope "/providers/Microsoft.Billing/billingAccounts/3a104626-eda0-5ebe-d5f1-b89c2f695ab4:0d98458f-e4e2-41e3-9ad3-8273661456f3_2019-05-31/billingProfiles/TGG6-335H-BG7-PGB/invoiceSections/e5116043-cae0-4b96-9882-9a7b43831c79" \
  --display-name "data-platform-prod" \
  --workload "Production"

# ---------------------------------------------------------------------------
# 1. Fix pre-existing bug: dev's Terraform state had flat resource addresses
#    left over from before the modules/ restructure. Without this, a plan
#    would have destroyed and recreated all 3 dev resources.
#    (Run from environments/dev, after `terraform init`.)
# ---------------------------------------------------------------------------
terraform state mv \
  'azurerm_resource_group.analytics' \
  'module.analytics_group.azurerm_resource_group.analytics'
terraform state mv \
  'azurerm_storage_account.analytics' \
  'module.analytics_group.azurerm_storage_account.analytics'
terraform state mv \
  'azurerm_consumption_budget_subscription.learning_guard' \
  'module.budget_alert.azurerm_consumption_budget_subscription.learning_guard'

# ---------------------------------------------------------------------------
# 2. Resource groups + remote state backend storage account
# ---------------------------------------------------------------------------
az group create -n rg-terraform-backend -l northeurope -o table
az group create -n rg-analytics-prod-neu-01 -l northeurope -o table   # dev's RG already existed

az storage account create -n "$SA_NAME" -g rg-terraform-backend -l northeurope \
  --sku Standard_LRS --min-tls-version TLS1_2 -o table

az storage container create -n tfstate --account-name "$SA_NAME" --auth-mode login

# ---------------------------------------------------------------------------
# 3. sp-terraform-dev: App Registration + Service Principal + OIDC + RBAC
# ---------------------------------------------------------------------------
az ad app create --display-name sp-terraform-dev --query "{appId:appId,id:id}" -o json
# -> appId: 5e93b219-9bc5-4a7b-8956-40d6c3648c1d
#    object id (app): 84ea5c02-7a2a-4184-94af-db13f30e8b42

az ad sp create --id 5e93b219-9bc5-4a7b-8956-40d6c3648c1d
# -> service principal object id: 2ea7cbfc-dd3c-400b-95ad-5c888993ac6d

az ad app federated-credential create --id 5e93b219-9bc5-4a7b-8956-40d6c3648c1d --parameters '{
  "name": "github-dev-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:oseliocandido/terraform-azure:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'
az ad app federated-credential create --id 5e93b219-9bc5-4a7b-8956-40d6c3648c1d --parameters '{
  "name": "github-dev-pr",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:oseliocandido/terraform-azure:pull_request",
  "audiences": ["api://AzureADTokenExchange"]
}'

export MSYS_NO_PATHCONV=1   # required from here on for every /subscriptions/... scope
az role assignment create --assignee 5e93b219-9bc5-4a7b-8956-40d6c3648c1d --role Contributor \
  --scope "/subscriptions/$SUB/resourceGroups/rg-analytics-dev-neu-01"
az role assignment create --assignee 5e93b219-9bc5-4a7b-8956-40d6c3648c1d --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/$SUB/resourceGroups/rg-terraform-backend/providers/Microsoft.Storage/storageAccounts/$SA_NAME"

# databricks-rg-rg-analytics-dev-neu-01 -- NOT one of this repo's own
# Terraform-managed resource groups; Databricks creates it itself as a side
# effect of the workspace (NAT gateway, DBFS storage, etc. -- see
# IMPLEMENTATION.md). It didn't exist yet when the Contributor grant above
# was first written, and RBAC on rg-analytics-dev-neu-01 doesn't cascade
# into a sibling RG -- so sp-terraform-dev had no access to it at all until
# this was added, which broke module.budget_alert_databricks_managed's own
# plan/apply the first time it ran under the CI service principal instead
# of a broader-permission local session (`reading Scoped Budget ...
# unexpected status 401`). Run this once the workspace's first apply has
# completed and the managed RG actually exists -- its name is deterministic
# (`databricks-rg-<main-rg-name>`) but the RG itself isn't, so this can't
# run any earlier.
az role assignment create --assignee 5e93b219-9bc5-4a7b-8956-40d6c3648c1d --role Contributor \
  --scope "/subscriptions/$SUB/resourceGroups/databricks-rg-rg-analytics-dev-neu-01"

# ---------------------------------------------------------------------------
# 4. sp-terraform-prod: same pattern, scoped to its own RG.
#    3 federated credentials: main-branch push and PR (for plan-prod, which
#    isn't gated by a GitHub Environment) plus environment:production
#    (for apply-prod, which is gated).
# ---------------------------------------------------------------------------
az ad app create --display-name sp-terraform-prod --query "{appId:appId,id:id}" -o json
# -> appId: f922b7ef-fa80-4230-b1aa-1c9798fe8ebf
#    object id (app): 9723d130-bc26-4a16-a905-a96a5a942d87

az ad sp create --id f922b7ef-fa80-4230-b1aa-1c9798fe8ebf
# -> service principal object id: fd71feac-167f-4008-b0eb-e7f5b0ef0d07

az ad app federated-credential create --id f922b7ef-fa80-4230-b1aa-1c9798fe8ebf --parameters '{
  "name": "github-prod-environment",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:oseliocandido/terraform-azure:environment:production",
  "audiences": ["api://AzureADTokenExchange"]
}'
az ad app federated-credential create --id f922b7ef-fa80-4230-b1aa-1c9798fe8ebf --parameters '{
  "name": "github-prod-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:oseliocandido/terraform-azure:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'
az ad app federated-credential create --id f922b7ef-fa80-4230-b1aa-1c9798fe8ebf --parameters '{
  "name": "github-prod-pr",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:oseliocandido/terraform-azure:pull_request",
  "audiences": ["api://AzureADTokenExchange"]
}'

az role assignment create --assignee f922b7ef-fa80-4230-b1aa-1c9798fe8ebf --role Contributor \
  --scope "/subscriptions/$SUB/resourceGroups/rg-analytics-prod-neu-01"
az role assignment create --assignee f922b7ef-fa80-4230-b1aa-1c9798fe8ebf --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/$SUB/resourceGroups/rg-terraform-backend/providers/Microsoft.Storage/storageAccounts/$SA_NAME"

# TODO once prod's databricks_workspace module has actually been applied
# and databricks-rg-rg-analytics-prod-neu-01 exists -- same gap as dev's
# identical grant above, same reason. Can't run this yet; the RG doesn't
# exist until that first apply completes.
# az role assignment create --assignee f922b7ef-fa80-4230-b1aa-1c9798fe8ebf --role Contributor \
#   --scope "/subscriptions/$SUB/resourceGroups/databricks-rg-rg-analytics-prod-neu-01"

# ---------------------------------------------------------------------------
# 5. Grant my own account data-plane access too (container create via
#    --auth-mode login worked off ARM-level access, but `terraform init
#    -migrate-state` needs actual blob data-plane RBAC).
# ---------------------------------------------------------------------------
az ad signed-in-user show --query "{id:id,upn:userPrincipalName}" -o json
# -> object id: 40000a06-c00f-44c4-b77d-c1e4eb1d451d

az role assignment create --assignee 40000a06-c00f-44c4-b77d-c1e4eb1d451d --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/$SUB/resourceGroups/rg-terraform-backend/providers/Microsoft.Storage/storageAccounts/$SA_NAME"

# ---------------------------------------------------------------------------
# 6. Terraform: point both environments at the new remote backend
#    (environments/dev/terraform.tf and environments/prod/terraform.tf edited
#    to a real `backend "azurerm" {}` block first -- not shown here, see
#    those files directly).
# ---------------------------------------------------------------------------
# from environments/dev:
terraform init -migrate-state -force-copy   # RBAC took ~15s to propagate before this worked
terraform plan -var-file=../common.tfvars -var-file=terraform.tfvars -lock-timeout=5m   # verify: 0 add, 0 destroy

# from environments/prod:
terraform init -input=false
terraform import -var-file=../common.tfvars -var-file=terraform.tfvars \
  'module.analytics_group.azurerm_resource_group.analytics' \
  "/subscriptions/$SUB/resourceGroups/rg-analytics-prod-neu-01"
terraform plan -var-file=../common.tfvars -var-file=terraform.tfvars -lock-timeout=5m   # verify: RG imported clean, storage+budget are new creates

# ---------------------------------------------------------------------------
# 7. Git remote (nothing pushed)
# ---------------------------------------------------------------------------
git remote add origin https://github.com/oseliocandido/terraform-azure.git

# ---------------------------------------------------------------------------
# 8. sp-databricks-account-admin: dedicated identity for Databricks
#    account-level Terraform (metastore, metastore assignment) -- see
#    docs/ARCHITECTURE.md "Metastore's own Azure
#    resources" and IMPLEMENTATION.md's Bootstrap section. Same
#    OIDC-federated-credential pattern as sp-terraform-dev/prod above -- no
#    client secret, ever. No Azure RBAC role assignment: this SP never
#    touches Azure resources directly, only the Databricks account API, so
#    there's nothing here for `az role assignment create` to scope.
#
#    The one step this script can't do: Databricks Account Admin can only
#    be granted by an existing admin, via Account Console (or the account
#    API authenticated as one) -- not an Azure Resource Manager operation,
#    so no `az` command exists for it. Done by hand, once, same bootstrap-
#    circularity category as everything else in this file.
# ---------------------------------------------------------------------------
az ad app create --display-name sp-databricks-account-admin --query "{appId:appId,id:id}" -o json
# -> appId: 378931a7-7f3f-4a8a-8110-624550571653
#    object id (app): 431a8eb2-58a6-486a-8fa5-f1ac2ed9bb44

az ad sp create --id 378931a7-7f3f-4a8a-8110-624550571653
# -> service principal object id: 262accf3-36d7-49f7-8aeb-49f8cd7df754

az ad app federated-credential create --id 378931a7-7f3f-4a8a-8110-624550571653 --parameters '{
  "name": "github-databricks-admin-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:oseliocandido/terraform-azure:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'
az ad app federated-credential create --id 378931a7-7f3f-4a8a-8110-624550571653 --parameters '{
  "name": "github-databricks-admin-pr",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:oseliocandido/terraform-azure:pull_request",
  "audiences": ["api://AzureADTokenExchange"]
}'

# Manual, in Databricks Account Console (accounts.azuredatabricks.net):
#   User management -> Service principals -> Add service principal ->
#   Microsoft Entra ID managed -> paste Application (client) ID
#   378931a7-7f3f-4a8a-8110-624550571653 -> toggle "Account admin" on.
# Confirmed done: 2026-09-11.

# ---------------------------------------------------------------------------
# 9. Cleanup: sp-terraform-sandbox -- deleted after removing the sandbox/
#    environment (see docs/analytics-platform/BACKLOG.md and the CI
#    workflow). This SP's own creation was never recorded in this file in
#    the first place (a pre-existing gap, not introduced by the sandbox
#    removal) -- discovered still present in Entra ID and cleaned up here.
#    Held subscription-wide Contributor (the exact broad grant
#    ADR-0001 -- since deleted -- flagged as narrower-than-ideal) plus
#    Storage Blob Data Contributor on the backend state storage account,
#    and one GitHub Actions federated credential
#    ("github-sandbox-dispatch"). Role assignments removed explicitly
#    first for a clean audit trail, then the App Registration itself
#    deleted (which removes its Service Principal and federated
#    credentials as child objects).
# ---------------------------------------------------------------------------
az role assignment delete --assignee f89cb098-cc7c-47b1-8f5c-510203b90cde --role Contributor \
  --scope "/subscriptions/$SUB"
az role assignment delete --assignee f89cb098-cc7c-47b1-8f5c-510203b90cde --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/$SUB/resourceGroups/rg-terraform-backend/providers/Microsoft.Storage/storageAccounts/$SA_NAME"

az ad app delete --id f89cb098-cc7c-47b1-8f5c-510203b90cde
# -> sp-terraform-sandbox, appId f89cb098-cc7c-47b1-8f5c-510203b90cde,
#    SP object id 0959180d-5b37-4723-958f-25cce461a0e8 -- deleted.

# ---------------------------------------------------------------------------
# 10. grp-marketing-*: the second domain's own Entra ID groups, same shape
#     as grp-sales-*'s (never individually recorded in this file either --
#     this is the first time that gap's been closed for a domain's groups).
#     mail-nickname == display-name, same convention already in use
#     (confirmed against grp-sales-data-governance-dev via `az ad group
#     show` before running this). Entra ID creation only -- see BACKLOG.md's
#     "Identity: group provisioning status" for which of these still need
#     the separate, manual Databricks-account-level registration step
#     before module.unity_catalog_marketing's enable_grants can flip to
#     true.
# ---------------------------------------------------------------------------
for env in dev prod; do
  for role in data-governance stakeholders analysts data-engineers; do
    name="grp-marketing-${role}-${env}"
    az ad group create --display-name "$name" --mail-nickname "$name"
  done
done
# -> grp-marketing-data-governance-dev   9bc287cb-c152-4f41-b66d-5349c67817dd
#    grp-marketing-stakeholders-dev      1fe07af3-41be-4858-9cf4-c815663dc6d6
#    grp-marketing-analysts-dev          b040a376-d3e7-4b22-b7c5-20b3f1b3c37c
#    grp-marketing-data-engineers-dev    6659b71b-df64-4c9c-ad4c-1eeb74ffd913
#    grp-marketing-data-governance-prod  63d4ce81-dbcc-46ee-97de-e1f7969b9b29
#    grp-marketing-stakeholders-prod     4735eb1a-6b7e-47a8-90e6-2f679bb12c04
#    grp-marketing-analysts-prod         5b2f5c2f-38cb-4845-9cde-9d4181bebc44
#    grp-marketing-data-engineers-prod   c1de470c-788f-41ab-9f8a-87c2696da7ae
# Confirmed created (Entra ID only, not yet registered at the Databricks
# account level): 2026-09-16.
