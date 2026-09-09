cd environments/prod

terraform init

terraform plan \
  -var-file=../common.tfvars \
  -var-file=terraform.tfvars \
  -out=tfplan.prod \
  -lock-timeout=5m

# (a) human review — readable form
terraform show tfplan.prod

# (d) machine check: list anything being deleted or replaced
terraform show -json tfplan.prod \
  | jq -r '.resource_changes[]
           | select(.change.actions | index("delete"))
           | .address'

# (b) apply exactly what was reviewed
terraform apply -lock-timeout=5m tfplan.prod
