# governance

Terraform root for the ABAC policies (column masks and row filters). Separate
from `platform/` so its plan never runs before the functions exist, and with its
own state key.

Run it after `platform` and `governance-bundle` (see `../governance-bundle/README.md`):

```bash
cd platform
export TF_VAR_workspace_url=$(terraform output -raw workspace_url)

cd ../governance
terraform init -reconfigure -backend-config=../config/dev/governance-backend.hcl
terraform plan -var-file=../config/common.tfvars -var-file=../config/dev/values.tfvars
```

The policies are off until `enable_mask_policy` / `enable_row_filter_policy` are
set. To protect a column, tag it, for example:

```sql
ALTER TABLE sales_dev.silver.customers ALTER COLUMN email SET TAGS ('sensitivity' = 'pii');
```
