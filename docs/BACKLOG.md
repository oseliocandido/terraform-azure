# Backlog — Retail Analytics Platform

Open work and known gaps only. What is already built is described in
[ARCHITECTURE.html](ARCHITECTURE.html) and [IMPLEMENTATION.html](IMPLEMENTATION.html).
Items are ordered roughly by how soon they matter.

## 1. Apply `prod` for the first time

Prod has never had a full apply; `apply-prod` waits on approval. Its state already
holds an early resource group, storage account and budget, kept by a `moved` block
(see IMPLEMENTATION.html, Prod bootstrap).

- Run the first apply locally as a metastore admin (the metastore grant is
  admin-only and ignored by CI).
- Expect the two-stage workspace apply (`-target` on the workspace, then a normal one).
- Nest `grp-databricks-ci-prod` in `grp-databricks-platform-prod` and every
  `grp-<domain>-data-governance-prod` (Entra ID); otherwise CI loses `MANAGE` on a
  catalog once ownership moves.
- Once the workspace exists, grant `sp-terraform-prod` `Cost Management Contributor`
  on the managed resource group (it also needs `Contributor` on the resource group).
- The `-prod` groups are registered (table below).

## 2. Groups

Created in Entra ID and registered in the Databricks account by hand (Account
Console → User management → Groups). Terraform only references them by name.

| Group | Status | Needed for |
|---|---|---|
| `grp-databricks-account-admins` | Registered | Owner of the metastore |
| `grp-databricks-ci-dev` / `-prod` | Registered; `-prod` not yet applied | Workspace membership and metastore `CREATE_*` for CI |
| `grp-databricks-platform-dev` / `-prod` | Registered | Owner of the credential, ingestion catalog, and landing/bronze locations |
| `grp-sales-{stakeholders,analysts,data-engineers,data-governance}-dev` | Registered | Sales catalog ownership and grants (`enable_grants = true` in dev) |
| `grp-sales-{stakeholders,analysts,data-engineers}-prod` | Registered | Sales grants in prod |
| `grp-sales-data-governance-prod` | Registered | Owner of `sales_prod` |
| `grp-marketing-data-governance-dev` | Registered | Owner of `marketing_dev` |
| `grp-marketing-{stakeholders,analysts,data-engineers}-dev` | Registered | Marketing business-group grants (`enable_grants = true` in dev) and dev workspace users |
| `grp-marketing-*-prod` (all four) | Registered | Marketing in prod, and prod's workspace users |

Marketing grants follow `var.enable_grants` like sales: on in dev, off in prod
until prod's first apply.

## 3. Ingestion pipeline

The infrastructure exists (landing containers and locations, `<system>_landing`
volumes, `checkpoints`, `ingestion_<env>.bronze`) but nothing consumes it. The
pipeline is out of scope here (PRD §16) and belongs in a Databricks Asset Bundle.

- **Consumer:** an Auto Loader stream (or a file-arrival Job) reading
  `<system>_landing` into bronze Delta tables, with state in `checkpoints`.
- **Pipeline service principals** for dev and prod, separate from `sp-terraform-*`
  and created with the same one-time `az` pattern; their grants are not defined.
  Until then `bronze_consumer_can_write` (true in dev) lets
  `grp-sales-data-engineers-dev` write to `checkpoints` and create tables in `bronze`.
- **Bronze access for a second domain:** `bronze_consumer_group_name` covers only
  `grp-sales-data-engineers-<env>`; add a grant when marketing needs raw data.

## 4. Compute

Dev has a serverless SQL warehouse (2X-Small, stops after 10 idle minutes) with
`CAN_USE` for every workspace group; prod has no compute. Grants and compute
permissions are separate: a user with `SELECT` still needs `CAN_USE` or
`CAN_ATTACH_TO` on some compute. No capacity study exists (PRD §3), so the
acceptance criterion "supports the expected initial data volumes" is deferred.

- **Compute for prod:** decide who needs it.
- **Enable the shared cluster** (`enable_cluster`, off): no classic cluster can
  start on this subscription in northeurope (4-vCPU sizes are
  `NotAvailableForSubscription` or have family quota 0; larger ones exceed the
  4 vCPU regional quota). To turn it on, upgrade from a trial subscription or open an
  Azure support request, confirm the node type with `az vm list-skus` and
  `az vm list-usage` (the default `Standard_DS3_v2` is a placeholder), set
  `enable_cluster = true` in `platform/compute.tf`, and check that standard access
  mode works on a single node.
- **Cluster access mode and runtime:** standard or dedicated (dedicated needs 15.4 LTS+
  for fine-grained access control), and whether to dedicate compute to one group.

Until then, serverless notebook compute covers Python and the warehouse covers SQL.

## 5. Delta retention for bronze, silver, and gold

The blob lifecycle policy covers `landing-*` only (it is unsafe for Delta tables),
so PRD §9's five-year retention is not met for bronze and silver data. Once a
pipeline exists, use `VACUUM` tuning (`delta.deletedFileRetentionDuration`,
`delta.logRetentionDuration`) and/or a partition-based archival job, and decide
whether silver and gold need any lifecycle handling.

## 6. Optional hardening

- **Bind the credential and external locations to workspaces.** They are `OPEN`
  today; `databricks_workspace_binding` (`storage_credential` / `external_location`)
  can bind them. Catalog roots are already covered by their catalog's binding.
- **Isolate the default `main` catalog.** It is `OPEN`, owned by a person, and gives
  `account users` `USE_CATALOG`, so every workspace on the metastore sees it.
- **Narrow CI's metastore privileges.** Each CI group holds `CREATE_CATALOG`,
  `CREATE_EXTERNAL_LOCATION` and `CREATE_STORAGE_CREDENTIAL` across the whole metastore.
- **Automate the metastore-grant bootstrap.** `databricks_grants.metastore_admins`
  is applied by hand and ignored by CI; a job with an admin identity would remove that.
- **Prod access narrower than dev (PRD §11).** Grants are identical today. The plan is
  to have pipeline service principals do the writes in prod, so no human group needs
  write access; revisit once they exist.
- **Scheduled drift detection.** The drift workflow is manual; uncomment its
  `schedule` to run weekly. It cannot see `ignore_changes` resources, and its prod job
  is only meaningful after prod's first apply.
- **Cost visibility (PRD §12).** Budgets only notify. Each workspace's NAT gateway
  costs about 31 EUR a month, more than the dev budget of 20 (accepted);
  `no_public_ip = false` would remove it but probably forces a workspace rebuild
  (not checked). Check whether the metastore's resource group has a budget, and tag
  compute for DBU cost.
- **Lint and security scanning.** CI runs `fmt`, `validate` and `plan` only; add
  `tflint` and `checkov` or `trivy config`.
- **Fine-grained DML privileges.** Engineers get blanket `MODIFY` because metastore
  privilege version 1.0 rejects `INSERT`/`UPDATE`/`DELETE` at catalog level. A newer
  version would allow a dev/prod `DELETE` distinction.

## 7. Accepted risk: `terraform destroy` ordering

`provider "databricks"` uses the workspace URL created in the same root, so
`terraform destroy` can delete the workspace while `databricks_*` objects are still in
state; they remain as orphaned state (recover with `terraform state rm`, then destroy
the Azure resources again). Accepted: a full destroy of `dev` is not planned. The fix
is two roots (one creates the workspace, one reads it); revisit if destroying `dev`
becomes routine.

## 8. Networking

No private endpoints, VNet injection or NSGs (PRD §16). The workspace uses Azure's
defaults: public URL, and Secure Cluster Connectivity (no public node IPs). Revisit
if a compliance or private-connectivity requirement appears.
