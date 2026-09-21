# Backlog — Retail Sales Analytics Platform

Open work and known gaps only. What is already built is described in
[ARCHITECTURE.md](ARCHITECTURE.md) and [IMPLEMENTATION.md](IMPLEMENTATION.md).
Items are ordered roughly by how soon they matter.

## 1. Apply `prod` for the first time

`environments/prod` is coded but has never been applied; `apply-prod` waits on
the `production` approval gate.

- Run the first apply locally as a metastore admin: the metastore grant is
  admin-only and CI plans ignore it.
- Register the `-prod` groups it references at the Databricks account level
  (table below). Verify `grp-sales-data-governance-prod` in particular; it was
  the last unregistered sales group.
- Expect the two-stage workspace apply (`-target` on the workspace, then a
  normal apply) and the manual metastore-grant step.
- A new domain catalog's first apply may also need an admin: CI loses `MANAGE`
  once ownership moves to the governance group.

## 2. Register the remaining groups

Groups are created in Entra ID (`docs/azure-setup-commands.sh`) and registered
at the Databricks account level by hand (Account Console → User management →
Groups). Terraform only references them by name.

| Group | Status | Needed for |
|---|---|---|
| `grp-databricks-account-admins` | Registered | Owner of the metastore |
| `grp-databricks-ci-dev` / `-prod` | Registered; `-prod` not yet applied | Workspace membership and metastore `CREATE_*` for CI |
| `grp-databricks-platform-dev` / `-prod` | Registered | Owner of the credential, ingestion catalog, and landing/bronze locations |
| `grp-sales-{stakeholders,analysts,data-engineers,data-governance}-dev` | Registered | Sales catalog ownership and grants (`enable_grants = true` in dev) |
| `grp-sales-{stakeholders,analysts,data-engineers}-prod` | Registered | Sales grants in prod |
| `grp-sales-data-governance-prod` | Verify | Owner of `sales_prod` |
| `grp-marketing-data-governance-dev` | Registered | Owner of `marketing_dev` |
| `grp-marketing-{stakeholders,analysts,data-engineers}-dev` | Not registered | Marketing business-group grants |
| `grp-marketing-*-prod` (all four) | Not registered | Marketing in prod |

**Enable marketing grants.** `unity_catalog_marketing` has `enable_grants` as a
literal `false` in both roots. Once its business groups are registered, switch
it to `var.enable_grants`.

## 3. Ingestion pipeline

The infrastructure exists (landing containers, read-only external locations
with file events, `<system>_landing` volumes, the `checkpoints`
volume, `ingestion_<env>.bronze`). Nothing consumes it yet; the pipeline is
out of scope for this repo (PRD §16) and belongs in a Databricks Asset Bundle.

- **Consumer:** an Auto Loader stream (or a Databricks Job with a file-arrival
  trigger) reading `<system>_landing` into bronze Delta tables, with state in the
  `checkpoints` volume (one folder per source system), or let Lakeflow pipelines
  manage checkpoints themselves and skip it.
- **Pipeline service principal:** a dedicated SP, different from
  `sp-terraform-*`, scoped to the workspace rather than Azure RBAC. Bootstrap
  it with the same one-time `az` CLI pattern as the Terraform SPs.
- **Checkpoint volume grants:** dev engineers hold `READ VOLUME`/`WRITE VOLUME`
  on `checkpoints` and `CREATE_TABLE` on the bronze schema, for hand-run
  experiments only (`bronze_consumer_can_write`). Prod has none. Once the SP
  exists, grant it those privileges and drop the human write access in dev.
- **Bronze read access for a second domain:** `bronze_consumer_group_name`
  covers only `grp-sales-data-engineers-<env>`. Add a grant for another
  domain's engineers when it has a real need for raw data.

## 4. Compute architecture

No compute resource (cluster, SQL warehouse, or serverless) or workspace-level
ACL is specified. Unity Catalog grants and compute permissions are separate: a
user with `SELECT` still needs `CAN_ATTACH_TO` on some compute in the
workspace. A capacity study is also missing (PRD §3 states no volume target).

Decide before adding it to ARCHITECTURE.md:

- Serverless SQL warehouses (fully managed, always Unity Catalog enforced)
  versus provisioned clusters.
- For clusters: access mode (standard or dedicated only; both reach Unity
  Catalog) and minimum runtime (dedicated needs 15.4 LTS+ for fine-grained
  access control).
- Whether to dedicate compute to a group such as
  `grp-sales-data-engineers-<env>` so attach rights and data grants align.
- Per-group ACLs (`CAN_ATTACH_TO`, `CAN_RESTART`, `CAN_MANAGE`) via
  `databricks_permissions`.

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
- **Fine-grained DML privileges.** Engineers get blanket `MODIFY` because the
  metastore's privilege version (1.0) rejects `INSERT`/`UPDATE`/`DELETE` at
  catalog level. Revisit if the privilege version is upgraded; it would allow
  a dev/prod `DELETE` distinction.

## 7. CI for `environments/shared`

The account-level metastore root has no CI job; every apply is manual with
`azure-cli` auth. `sp-databricks-account-admin` exists to make this
automatable. If added, gate it like `prod` (a mistake affects every
environment's metastore access), not auto-apply-on-merge.

## 8. Accepted risk: `terraform destroy` ordering

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

## 9. Networking

No private endpoints, VNet injection, or NSGs (PRD §16, ARCHITECTURE.md
"Networking"). The workspace uses Azure's defaults: public workspace URL
reachable and Secure Cluster Connectivity (no public IPs on nodes) on, both
matching the live `dev` workspace. Revisit if a compliance or private
connectivity requirement appears; it would need its own ADR.
