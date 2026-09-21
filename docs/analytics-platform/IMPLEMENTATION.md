# Implementation — Retail Sales Analytics Platform

What is built, object by object. [ARCHITECTURE.md](../ARCHITECTURE.md) explains
the design; this document lists every module, the objects it creates, and the
mechanics that matter when operating it. The repo is the source of truth for exact
arguments.

**Status.** `dev` is applied and converged (`terraform plan` shows no changes).
`prod` is coded identically but never applied; see [Prod bootstrap](#prod-bootstrap).

## Layout

```text
modules/
├── analytics/          RG, storage account, containers, landing retention
├── budget_alert/       RG-scoped budget with spend alerts
└── databricks/
    ├── workspaces/     workspace, access connector, metastore assignment
    ├── storage/        once per environment: credential, external locations, ingestion catalog
    └── unity_catalog/  once per domain: catalog, silver/gold, grants
environments/
├── common.tfvars       values shared by every root (passed with -var-file, not auto-loaded)
├── dev/  prod/         root modules, own state and tfvars
└── shared/             account-level metastore, applied by hand
.github/workflows/      terraform.yml (plan/apply), drift-detection.yml (manual)
```

`storage` is separate from `unity_catalog` because the credential and the raw
ingestion layer are environment-wide, not per domain. Module state addresses come
from the call label, not the `source` path.

## Objects by module

### `modules/analytics`

| Object | What it is | Notes |
|---|---|---|
| `azurerm_resource_group.analytics` | The environment's resource group, `rg-<workload>-<env>-<region>-<n>` | Tagged |
| `azurerm_storage_account.analytics` / `.analytics_protected` | ADLS Gen2 account (hierarchical namespace, TLS 1.2, private, AAD-only, no shared keys) | GZRS in prod, LRS elsewhere. Soft delete 14 days in prod, 7 elsewhere. Versioning off. The `_protected` twin exists only in prod and has `prevent_destroy` |
| `azurerm_storage_container.bronze` | Storage for the raw `ingestion_<env>.bronze` schema | Same `_protected` twin pattern in prod. No lifecycle policy (Delta) |
| `azurerm_storage_container.landing["<system>"]` | `landing-<system>`, where a source system writes raw files | `for_each` over `landing_source_systems` (`pos`, `ecommerce`) |
| `azurerm_storage_container.managed` | `managed-sales`, storage root of the sales catalog | |
| `azurerm_storage_container.managed_domain["<domain>"]` | `managed-<domain>` for each entry in `additional_domains` (`marketing`, `ingestion`) | `ingestion` backs the non-domain catalog |
| `azurerm_storage_management_policy.default_retention_policy` | Tier to cool at 90 days, archive at 1 year, delete at 5 years | Landing containers only, because a blob-age rule cannot see the Delta log |

Outputs: `resource_group_id`, `resource_group_name`, `storage_account_id`,
`storage_account_name`, `bronze_container_name`, `landing_container_names`,
`managed_container_name`, `additional_managed_container_names`.

**Why twins.** `prevent_destroy` must be a literal, so it cannot be limited to prod
with a variable. The account and every container are declared twice (normal and
`*_protected`), chosen by `count`/`for_each` on `local.is_prod`. Locals pick
whichever exists, so outputs are identical. To destroy a prod resource on purpose,
remove its `prevent_destroy` in a reviewed change first.

A new source system is one entry in `landing_source_systems`; its container,
retention prefix, external location, and volumes follow from it.

### `modules/budget_alert`

| Object | What it is |
|---|---|
| `azurerm_consumption_budget_resource_group.learning_guard` | Monthly budget on one resource group, notifying by email at 20% and 40% of the amount |

Used twice per environment: on the analytics resource group and on the Databricks
workspace's own managed resource group.

### `modules/databricks/workspaces`

| Object | What it is | Notes |
|---|---|---|
| `azurerm_databricks_workspace.this` | The Databricks workspace, `dbw-...` | Premium SKU (required for Unity Catalog). Optional `managed_resource_group_name` is ForceNew |
| `azurerm_databricks_access_connector.this` | Managed identity Databricks uses to reach storage, `dbac-...` | System-assigned |
| `azurerm_role_assignment.access_connector_storage` | `Storage Blob Data Contributor` for the connector on the storage account | The only identity that can read the data |
| `databricks_metastore_assignment.this` | Links the workspace to the shared metastore | Also restores the link if the metastore is recreated |

Outputs: `workspace_id`, `workspace_url`, `access_connector_id`, `managed_resource_group_id`.
The credential and external locations are not here: they need metastore grants, and
this module holds the workspace the `databricks` provider's `host` depends on, so
depending on those grants would create a cycle.

### `modules/databricks/storage` (once per environment)

Everything is owned by `grp-databricks-platform-<env>`, referenced as a bare string
so the group needs no workspace membership.

| Object | What it is | Notes |
|---|---|---|
| `databricks_storage_credential.analytics` | `cred-analytics-<env>`, wraps the access connector | One per environment |
| `databricks_external_location.bronze` | Registers the `bronze` container | File events **off** (Databricks defaults them on) |
| `databricks_external_location.landing["<system>"]` | Registers a landing container | Read-only, file events **on** (managed queue) |
| `databricks_external_location.ingestion_managed` | Registers `managed-ingestion`, the ingestion catalog's root | |
| `databricks_catalog.ingestion` | `ingestion_<env>`, the non-domain catalog for raw data | `ISOLATED` |
| `databricks_workspace_binding.ingestion` | Binds that catalog to this environment's workspace | |
| `databricks_schema.bronze` | The only bronze schema in the platform | Stored in the `bronze` container |
| `databricks_volume.landing["<system>"]` | EXTERNAL volume `<system>_landing` over a landing location | Group-owned |
| `databricks_volume.checkpoints` | MANAGED volume for Auto Loader state, one folder per system | Stored in the `bronze` container (the schema's root overrides the catalog's) |
| `databricks_grants.credential_ci`, `bronze_ci`, `landing_ci`, `ingestion_managed_ci` | CI: `CREATE_EXTERNAL_LOCATION` on the credential, `CREATE_EXTERNAL_TABLE` on each location | Ownership does not cascade to CI |
| `databricks_grants.ingestion_catalog` | CI: `USE_CATALOG`, `USE_SCHEMA`, `CREATE_SCHEMA`, `CREATE_VOLUME`, `READ METADATA`, `READ VOLUME`. Consumer group: `USE_CATALOG` | One grants resource per securable |
| `databricks_grants.bronze_schema` | Consumer group: `USE_SCHEMA`, `SELECT` (+ `CREATE_TABLE` if `bronze_consumer_can_write`) | Gated by `enable_grants` |
| `databricks_grants.landing_volume` | Consumer group: `READ VOLUME` | Gated. Never write: source systems write outside Unity Catalog |
| `databricks_grants.checkpoints_volume` | Consumer group: `READ VOLUME`, `WRITE VOLUME` | Only when `enable_grants` and `bronze_consumer_can_write` (dev) |

Inputs: `environment`, `metastore_id`, `workspace_id`, `access_connector_id`,
`resource_group_name`, `subscription_id`, `ci_group_name`, `ci_service_principal_name`,
`enable_grants`, `bronze_consumer_can_write`, `bronze_consumer_group_name`,
`bronze_storage_root`, `landing_storage_roots`, `ingestion_catalog_storage_root`.
Output: `storage_credential_name`.

### `modules/databricks/unity_catalog` (once per domain)

Inputs: `environment`, `domain` (required), `metastore_id`, `workspace_id`,
`storage_credential_name`, `catalog_storage_root`, `ci_service_principal_name`,
`ci_group_name`, `enable_grants`. Group names derive from `var.domain`; the owner is
`grp-<domain>-data-governance-<env>`.

| Object | What it is | Notes |
|---|---|---|
| `databricks_catalog.this` | `<domain>_<env>`, for example `sales_dev` | `ISOLATED`, storage root is the domain's `managed-<domain>` container |
| `databricks_workspace_binding.this` | Binds the catalog to this environment's workspace | |
| `databricks_external_location.managed` | Registers the domain's catalog root | Owned by the governance group |
| `databricks_schema.silver`, `.gold` | Refined and business-ready schemas | MANAGED (no storage root). Depend on the catalog grants so CI can create them |
| `databricks_grants.managed_ci` | CI: `CREATE_EXTERNAL_TABLE` and `CREATE MANAGED STORAGE` on the root | Lets CI use it as a catalog root |
| `databricks_grants.catalog` | Stakeholders and analysts: `USE_CATALOG`. Engineers: `USE_CATALOG`, `USE_SCHEMA`, `SELECT`, `MODIFY`. CI: `USE_CATALOG`, `USE_SCHEMA`, `CREATE_SCHEMA`, `READ METADATA` | Business groups gated by `enable_grants`; CI always on |
| `databricks_grants.gold_schema` | Stakeholders and analysts: `USE_SCHEMA`, `SELECT` | Gated |
| `databricks_grants.silver_schema` | Analysts: `USE_SCHEMA`, `SELECT` | Gated |

Engineers use blanket `MODIFY` because the metastore's privilege version (1.0)
rejects `INSERT`/`UPDATE`/`DELETE` at catalog level. `databricks_grants` (plural,
authoritative) is used over `databricks_grant` so Terraform is the single source of truth.

`enable_grants` gates business-group grants only. Sales uses `var.enable_grants`
(true in dev); marketing uses a literal `false` until its groups are registered.

## Root modules (`environments/dev`, `environments/prod`)

| Object | What it is |
|---|---|
| `module.analytics_group`, `budget_alert` | Resource group, storage, and the budget (`additional_domains = ["marketing", "ingestion"]`) |
| `module.databricks_workspace`, `budget_alert_databricks_managed` | Workspace and access connector, plus a budget on the workspace's managed resource group |
| `databricks_permission_assignment.ci_group` | Makes `grp-databricks-ci-<env>` a workspace `ADMIN` (needed to manage permission assignments) |
| `databricks_entitlements.ci_group` | Gives that group `workspace_access`, without which the workspace API is unusable |
| `databricks_grants.metastore_admins` | `CREATE_CATALOG`, `CREATE_EXTERNAL_LOCATION`, `CREATE_STORAGE_CREDENTIAL` for both CI groups. `ignore_changes = [grant]` |
| `module.platform_storage` | The `storage` module; depends on the metastore grant |
| `module.unity_catalog_sales`, `module.unity_catalog_marketing` | The `unity_catalog` module once per domain |

The metastore grant is in each root because `databricks_grants` needs the
workspace-level provider, which the account-level `shared` root lacks. Dev's and
prod's copies are identical so they converge. Grants go to the CI **group**, not the
service principal, so a new CI identity is a membership change. `moved` blocks
cover the earlier `unity_catalog` → `unity_catalog_sales` rename.

## Providers and authentication

The `databricks` provider's `host` comes from `module.databricks_workspace.workspace_url`.
Locally it uses `auth_type = "azure-cli"`; in CI it uses the same OIDC variables as
`azurerm`. A dummy `databricks_account_id` variable keeps the shared `common.tfvars`
from warning.

**Two-stage first apply.** A provider block cannot reference a computed attribute, so
on a new environment the workspace must exist before the `databricks` provider can
be configured: first `terraform apply -target=module.databricks_workspace.azurerm_databricks_workspace.this`,
then a normal apply. The workspace stays `azurerm` permanently because the
`databricks` provider cannot create Azure workspaces. Resource-group `Contributor`
is enough to create it and the access connector.

## CI permission model

CI runs as `sp-terraform-<env>` (a member of `grp-databricks-ci-<env>`), which is
**not** a metastore admin.

| Constraint | Consequence |
|---|---|
| Ownership does not cascade | CI holds explicit grants on everything it reads or creates against (see the grants above) |
| Transferring ownership drops the creator's `MANAGE` | A catalog CI creates and hands to a group cannot be finished by CI, so a new domain's first apply may need a metastore admin |
| Metastore grants are admin-only | A non-admin cannot update them and only sees grants for its own groups, which shows as a phantom diff. Hence `ignore_changes`; apply them locally as an admin. Drift on them is not reported |
| Saved plans go stale | `apply-*` applies the plan artifact from `plan-*`; on "Saved plan is stale" re-run the whole workflow |

`drift-detection.yml` is a manual workflow that never applies. It runs `plan -refresh-only`
(state vs Azure/Databricks; a warning, since it can show provider spelling noise) and a
plain `plan` (code vs reality; fails on any diff). `environments/shared` has no CI job.

## Naming

| Object | Pattern | Example |
|---|---|---|
| Workspace, access connector | `dbw-` / `dbac-<workload>-<env>-<region>-<n>` | `dbw-analytics-dev-neu-01` |
| Storage credential | `cred-analytics-<env>` | `cred-analytics-dev` |
| External locations | `loc-analytics-<env>-<bronze\|landing-<system>\|ingestion-managed\|<domain>-managed>` | `loc-analytics-dev-landing-pos` |
| Catalogs | `<domain>_<env>`, `ingestion_<env>` | `sales_dev` |
| Schemas | `bronze` (ingestion only), `silver`, `gold` | |
| Volumes | `<system>_landing`, `checkpoints` | `pos_landing` |
| Groups | `grp-<domain>-{stakeholders,analysts,data-engineers,data-governance}-<env>`, `grp-databricks-{platform,ci}-<env>` | `grp-sales-analysts-dev` |

Groups are created in Entra ID and registered in the Databricks account by hand;
Terraform only references them by name.

## `environments/shared`

Account-level root with its own state. It reads only `common.tfvars` and manages one
object: `databricks_metastore.primary` (`metastore_azure_northeurope`, owned by
`grp-databricks-account-admins`). `terraform output metastore_id` is the source of
truth; copy it to `common.tfvars` if the metastore is ever recreated. `storage_root`
is ForceNew.

## Bootstrap

**Metastore.** Created once by hand, like the App Registrations. Databricks
auto-creates an empty default metastore when a region's first workspace appears;
adopt it with `terraform import` rather than fighting it. The Account Console does not
work until one Azure Databricks workspace exists, so for a new tenant: (1) apply the
workspace for one environment, (2) in the Account Console create the metastore's
resource group, storage account and access connector, then the metastore, and assign
it, (3) if Databricks auto-created a metastore first, fill in its storage config
instead of creating another. Never wire the pre-staged access connector in the
workspace's managed resource group to anything: it inherits that workspace's lifecycle
and cannot be deleted.

**Groups.** Create each `grp-*` group in Entra ID (`docs/azure-setup-commands.sh`) and
register it in the Databricks account before any grant that references it applies.

## Prod bootstrap

`environments/prod` has never been applied; `apply-prod` waits on the `production`
approval. Before approving it:

1. Run the first prod apply locally as a metastore admin (the metastore grant is
   admin-only and ignored by CI).
2. Register the `-prod` groups the config references: `grp-databricks-ci-prod`,
   `grp-databricks-platform-prod`, and `grp-sales-*-prod`. `grp-marketing-*-prod`
   may stay unregistered.
3. Expect the two-stage workspace apply on the first run.
