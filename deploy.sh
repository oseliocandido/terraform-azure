terraform init -backend-config=env/prod.backend.hcl

terraform plan \
  -var-file=env/prod.tfvars \
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