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
