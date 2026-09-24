# Backlog — Retail Sales Analytics Platform

Open work and known gaps only. What is already built is described in
[ARCHITECTURE.html](ARCHITECTURE.html) and [IMPLEMENTATION.html](IMPLEMENTATION.html).
Items are ordered roughly by how soon they matter.

## 1. Apply `prod` for the first time

Prod (`platform` with `config/prod/values.tfvars`) is coded but has never had a
full apply; `apply-prod` waits on the `production` approval gate. Its state
already holds an early resource group, storage account and budget; a `moved`
block in `main.tf` keeps them (see IMPLEMENTATION.html, Prod bootstrap).

- Run the first apply locally as a metastore admin: the metastore grant is
  admin-only and CI plans ignore it.
- The `-prod` groups it references are registered at the Databricks account
  level (table below).
- Expect the two-stage workspace apply (`-target` on the workspace, then a
  normal apply) and the manual metastore-grant step.
- Nest `grp-databricks-ci-prod` in `grp-databricks-platform-prod` and in every
  `grp-<domain>-data-governance-prod` group (Entra ID). Without it CI loses
  `MANAGE` on a catalog as soon as ownership moves to the governance group.
- After the workspace exists, grant `sp-terraform-prod` `Cost Management
  Contributor` on the workspace's managed resource group, by hand (it also
  needs `Contributor` on the resource group).

## 2. Groups and marketing grants

Groups are created in Entra ID and registered at the Databricks account level by
hand (Account Console → User management → Groups). Terraform only references them
by name.

| Group | Status | Needed for |
|---|---|---|
| `grp-databricks-account-admins` | Registered | Owner of the metastore |
| `grp-databricks-ci-dev` / `-prod` | Registered; `-prod` not yet applied | Workspace membership and metastore `CREATE_*` for CI |
| `grp-databricks-platform-dev` / `-prod` | Registered | Owner of the credential, ingestion catalog, and landing/bronze locations |
| `grp-sales-{stakeholders,analysts,data-engineers,data-governance}-dev` | Registered | Sales catalog ownership and grants (`enable_grants = true` in dev) |
| `grp-sales-{stakeholders,analysts,data-engineers}-prod` | Registered | Sales grants in prod |
| `grp-sales-data-governance-prod` | Registered | Owner of `sales_prod` |
| `grp-marketing-data-governance-dev` | Registered | Owner of `marketing_dev` |
| `grp-marketing-{stakeholders,analysts,data-engineers}-dev` | Registered | Marketing business-group grants (still off, see below) and dev workspace users |
| `grp-marketing-*-prod` (all four) | Registered | Marketing in prod, and prod's workspace users |

**Enable marketing grants.** All marketing groups are registered, so this is
unblocked. `unity_catalog_marketing` still has `enable_grants` as a literal
`false` in `platform/catalogs.tf`; switch it to `var.enable_grants` (a code
change, applied in dev first).

## 3. Ingestion pipeline

The infrastructure exists (landing containers, read-only external locations
with file events, `<system>_landing` volumes, the `checkpoints`
volume, `ingestion_<env>.bronze`). Nothing consumes it yet; the pipeline is
out of scope for this repo (PRD §16) and belongs in a Databricks Asset Bundle.

- **Consumer:** an Auto Loader stream (or a Databricks Job with a file-arrival
  trigger) reading `<system>_landing` into bronze Delta tables, with state in the
  `checkpoints` volume (one folder per source system), or let Lakeflow pipelines
  manage checkpoints themselves and skip it.
- **Pipeline service principals for dev and prod:** dedicated SPs, separate from
  `sp-terraform-*`, scoped to the workspace rather than Azure RBAC and created with
  the same one-time `az` CLI pattern as the Terraform SPs. Their grants in dev and
  prod are not defined yet. Until then `bronze_consumer_can_write` (true in dev,
  false in prod) lets `grp-sales-data-engineers-dev` write to the `checkpoints`
  volume and create tables in `bronze`.
- **Bronze read access for a second domain:** `bronze_consumer_group_name`
  covers only `grp-sales-data-engineers-<env>`. Add a grant for another
  domain's engineers when it has a real need for raw data.

## 4. Compute architecture

Dev has a serverless SQL warehouse (`modules/databricks/compute`, 2X-Small,
stops after 10 idle minutes) with `CAN_USE` for every workspace group. A
single-node cluster exists behind `enable_cluster` (off, see 4a), and prod has
no compute yet. Unity Catalog grants and compute permissions are separate: a
user with `SELECT` still needs `CAN_ATTACH_TO` (cluster) or `CAN_USE`
(warehouse) on some compute. A capacity study is still missing (PRD §3 states
no volume target). The PRD acceptance criterion "supports the expected initial
data volumes" is deferred with this: it can't be checked until compute is
sized against a real volume figure.

Still to decide:

- Compute for prod, and who needs it.
- For clusters, once one can run: access mode (standard or dedicated only; both
  reach Unity Catalog), minimum runtime (dedicated needs 15.4 LTS+ for
  fine-grained access control), and whether to dedicate compute to a group such
  as `grp-sales-data-engineers-<env>` so attach rights and data grants align.

## 4a. Enable the shared cluster

`modules/databricks/compute` creates a serverless SQL warehouse in dev. Its
single-node cluster is off (`enable_cluster = false`) because no classic cluster
can start on the current subscription in northeurope: the supported 4-vCPU node
types are `NotAvailableForSubscription` or have a family quota of 0, and larger
ones exceed the 4 vCPU regional quota. To turn it on:

- Lift the restriction and raise the quota, either by upgrading from a trial
  subscription to pay-as-you-go or with an Azure support request.
- Confirm the node type with `az vm list-skus` and `az vm list-usage` (the
  default `Standard_DS3_v2` is a placeholder), then set `enable_cluster = true`
  in the `module "compute"` call in `platform/compute.tf`.
- Confirm standard access mode is accepted on a single node; if not, switch to
  dedicated access mode for one group.

Until then, serverless notebook compute covers Python, and the warehouse covers
SQL only.

## 5. Delta retention for bronze, silver, and gold

The blob lifecycle policy covers `landing-*` only (it is unsafe for Delta
tables, which it cannot see into). PRD §9's "queryable at lower cost" half of
the five-year retention is therefore not met for bronze/silver data. Needs a
Delta-native mechanism once a pipeline exists: `VACUUM` tuning
(`delta.deletedFileRetentionDuration`, `delta.logRetentionDuration`) and/or a
partition-based archival job. Also decide whether silver/gold need any
lifecycle handling once real volumes exist.

## 6. Optional hardening

- **Bind the storage credential and external locations to workspaces.** They
  are `OPEN` (visible from any workspace on the metastore) today. They can be
  bound with `databricks_workspace_binding` (`securable_type`
  `storage_credential` / `external_location`), and isolation is enforced when
  a privilege is used. Catalog roots are already covered by their catalog's
  binding; the landing and bronze locations rely on grants and RBAC.
- **Narrow CI's metastore privileges.** Each environment's CI group holds
  `CREATE_CATALOG`, `CREATE_EXTERNAL_LOCATION`, and `CREATE_STORAGE_CREDENTIAL`
  across the whole metastore, not only its own environment.
- **Automate the metastore-grant bootstrap.** `databricks_grants.metastore_admins`
  is applied by hand by a metastore admin and ignored by CI (drift is not
  reported). Running it from a job with an admin identity would remove that
  manual step.
- **Prod access narrower than dev (PRD §11).** Grants are identical in dev
  and prod today (engineers get `MODIFY` on the catalog in both). The plan is
  to keep them the same and have automated service principals do the writes in
  prod, so no human group needs write access there. Revisit once those
  pipeline SPs exist.
- **Enable scheduled drift detection.** `.github/workflows/drift-detection.yml`
  runs a refresh-only plan (warning) and a plain plan against `main` (fails on any
  diff), but it is manual-only. Uncomment its `schedule` to run it weekly. It cannot
  see drift in resources with `ignore_changes` (the metastore grant), and its prod
  job is only meaningful after prod's first apply.
- **Cost visibility (PRD §12).** Tags and per-resource-group budgets exist, but
  budgets only notify. Each workspace's NAT gateway costs about 1 EUR a day
  (about 31 EUR a month) with no compute running, more than the dev budget of
  20; this is accepted. `no_public_ip = false` on the workspace would remove it
  but probably forces a workspace rebuild (not checked). Check whether the
  metastore's own resource group has a budget, and tag compute for DBU cost.
- **Lint and security scanning.** CI runs `fmt`, `validate`, and `plan` only.
  Add `tflint` and a scanner such as `checkov` or `trivy config`.
- **Fine-grained DML privileges.** Engineers get blanket `MODIFY` because the
  metastore's privilege version (1.0) rejects `INSERT`/`UPDATE`/`DELETE` at
  catalog level. Revisit if the privilege version is upgraded; it would allow
  a dev/prod `DELETE` distinction.

## 7. Accepted risk: `terraform destroy` ordering

`provider "databricks"` is configured from a computed attribute of a resource
created in the same root (`module.databricks_workspace.workspace_url`).
`terraform destroy` can delete the workspace while `databricks_*` objects are
still in state; the provider then cannot resolve its host, and those objects
remain as orphaned state (recover with `terraform state rm`, then destroy the
Azure resources again).

Accepted for now: a full destroy of `dev` is not planned. The fix is two roots
(one creating the workspace, one reading it via a `data` source). Revisit
before duplicating the structure further, or if destroying `dev` becomes
routine.

## 8. Networking

No private endpoints, VNet injection, or NSGs (PRD §16, ARCHITECTURE.html
"Networking"). The workspace uses Azure's defaults: public workspace URL
reachable and Secure Cluster Connectivity (no public IPs on nodes) on, both
matching the live `dev` workspace. Revisit if a compliance or private
connectivity requirement appears; it would need its own design decision.
