# Architecture — Retail Sales Analytics Platform

Target Azure/Databricks/Terraform architecture that satisfies
[PRD.md](PRD.md)'s business requirements. This is a **future-phase**
design — it builds on top of, and must not duplicate or contradict, the
infrastructure already implemented and documented in
[`../ARCHITECTURE.md`](../ARCHITECTURE.md) and
[`../adr/0001-sandbox-subscription-scope.md`](../adr/0001-sandbox-subscription-scope.md) /
[`../adr/0002-pipeline-and-identity-architecture.md`](../adr/0002-pipeline-and-identity-architecture.md)
(the currently-real `analytics_group` + `budget_alert` modules, per-environment
OIDC identity, and the plan/apply CI/CD pipeline).

**Scope boundary:** this document covers infrastructure only — the Azure
and Databricks resources that must exist for a sales analytics pipeline to
be *buildable* later. It deliberately excludes anything that is a
data-pipeline/transformation design decision (schema design, how change
over time is captured within a table, data-quality rules, orchestration).
Those belong to whoever implements the actual pipeline, out of scope per
[PRD.md §5](PRD.md).

Each decision below follows the same Context/Decision/Consequences format
as `../adr/0001-*` and `../adr/0002-*`, kept inline in this one document
rather than as separate numbered ADR files, since these are future-phase
design calls rather than decisions already acted on. Resource names and
arguments below are taken from the current `hashicorp/azurerm` and
`databricks/databricks` Terraform provider documentation — see
[IMPLEMENTATION.md](IMPLEMENTATION.md) for the full HCL.

---

## Azure resource architecture

**Context.** The existing foundation (`../ARCHITECTURE.md` §2) already
gives each environment its own resource group
(`rg-analytics-dev-neu-01`, `rg-analytics-prod-neu-01`), and a resource
group already represents one business case per environment — this project
adds one business case (Sales), not several, which is why the platform
doesn't need per-department resource groups.

**Decision.** The Databricks workspace, its access connector, and the new
storage containers all live inside each environment's *existing* resource
group — no second resource group per environment.

**Consequences.** RBAC scoping (`sp-terraform-dev`/`-prod` are Contributor
on exactly one RG each) continues to work unmodified.

---

## Storage architecture: `azurerm_storage_account` containers

**Context.** Each environment's existing ADLS Gen2 storage account
(`modules/analytics_group`) needs somewhere to land sales data at
different processing stages.

**Decision.** Three `azurerm_storage_container` resources per environment
on the existing account (hierarchical namespace is already enabled, so
these behave as ADLS Gen2 directories, not flat blob containers):

```hcl
resource "azurerm_storage_container" "bronze" {
  name                  = "bronze"
  storage_account_id    = azurerm_storage_account.analytics.id
  container_access_type = "private"
}
# "silver" and "gold" follow the same shape
```

**Consequences.** No new storage account is created — this reuses the
account `modules/analytics_group` already provisions, consistent with
PRD §13's "no unnecessary coupling" and the existing account's global name
already being a scarce, hard-won resource (see `../ARCHITECTURE.md` §2 on
the `stanalyticsprodneu01b` naming collision).

---

## Analytical data layering

**Context.** [PRD.md §8](PRD.md#8-analytical-data-organization) requires
raw → intermediate → business-ready staging, without prescribing the
mechanism, and explicitly excludes how transformations or historical
change are implemented (that's pipeline logic).

**Decision.** Medallion layering as a **storage and catalog structure
only** — `bronze`/`silver`/`gold` containers (above) map one-to-one to
`bronze`/`silver`/`gold` Unity Catalog schemas (below). What actually
writes data into each layer, and how, is out of scope here.

**Consequences.** This is purely a storage/metadata-organization decision.
No transformation logic, schema-on-write validation, or data-quality
tooling is implied or required by this infrastructure.

---

## Data retention and lifecycle policy

**Context.** [PRD.md §9](PRD.md#9-historical-data-retention) sets an
explicit business requirement: five years of retention, with older data
allowed to sit in a cheaper storage tier before that point. This is the
one PRD requirement that maps directly onto a concrete Azure resource
rather than a design decision left to a future pipeline.

**Decision.** One `azurerm_storage_management_policy` per environment's
storage account, with a lifecycle rule scoped to the `bronze/` prefix
(the raw, full-history layer — `silver`/`gold` are derived and can be
rebuilt from `bronze`, so they don't need the same multi-year retention):

```hcl
resource "azurerm_storage_management_policy" "sales_retention" {
  storage_account_id = azurerm_storage_account.analytics.id

  rule {
    name    = "bronze-retention"
    enabled = true

    filters {
      prefix_match = ["bronze/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 90
        tier_to_archive_after_days_since_modification_greater_than = 365
        delete_after_days_since_modification_greater_than          = 1825 # 5 years
      }
    }
  }
}
```

**Consequences.** The five-year business requirement is now an enforced
Azure policy, not a convention someone has to remember — data older than
1825 days is deleted automatically regardless of whether any pipeline
process ever runs. `silver`/`gold` are left unmanaged by this policy for
now; if they accumulate meaningfully, they get their own rule when a
pipeline actually populates them.

---

## Databricks workspace architecture

**Context.** PRD requires Databricks as the analytical compute platform
(§14), with no networking requirement yet (§16 backlog).

**Decision.** One `azurerm_databricks_workspace` per environment, `sku =
"standard"` (no need for `premium`-only features like
`infrastructure_encryption_enabled` at this phase), default
`public_network_access_enabled = true` (VNet injection via
`custom_parameters` is deliberately not configured — see "Networking,
deferred" below):

```hcl
resource "azurerm_databricks_workspace" "sales" {
  name                = "dbw-analytics-${var.environment}-neu-01"
  resource_group_name = azurerm_resource_group.analytics.name
  location             = var.location
  sku                  = "standard"
}
```

**Consequences.** Azure Databricks creates its own *managed* resource
group (`managed_resource_group_name`, auto-named unless set explicitly) to
hold cluster-support infrastructure it controls directly — that managed RG
is outside this project's Terraform state and RBAC model by design; it's
Databricks' own operational concern, not this platform's.

---

## Unity Catalog: storage access (`azurerm_databricks_access_connector` + `databricks_storage_credential`)

**Context.** Unity Catalog needs a credential to read/write the ADLS Gen2
containers above. PRD §11 requires least-privilege, identity-based access
over static credentials.

**Decision.** An Azure Databricks Access Connector (a managed identity
purpose-built for this) per environment, granted `Storage Blob Data
Contributor` on the storage account, referenced by a
`databricks_storage_credential` using its `azure_managed_identity` block
— **not** `azure_service_principal`, which requires a long-lived client
secret and is the legacy pattern the current provider docs advise against:

```hcl
resource "azurerm_databricks_access_connector" "sales" {
  name                = "dbac-analytics-${var.environment}-neu-01"
  resource_group_name = azurerm_resource_group.analytics.name
  location             = var.location
  identity {
    type = "SystemAssigned"
  }
}

resource "databricks_storage_credential" "sales" {
  name = "cred-analytics-${var.environment}"
  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.sales.id
  }
}
```

**Consequences.** No Databricks-side secret to rotate or leak — the trust
relationship is an Azure-native managed identity + RBAC role assignment,
the same pattern this repo already uses for CI/CD (`../adr/0002-*`), just
applied to Unity Catalog's own storage access instead of Terraform's.

---

## Unity Catalog: external locations

**Context.** Unity Catalog requires each storage path it manages to be
explicitly registered, rather than trusting any path the credential above
could technically reach.

**Decision.** One `databricks_external_location` per container, each
pointing at exactly one of the three containers and using the credential
above:

```hcl
resource "databricks_external_location" "bronze" {
  name            = "loc-analytics-${var.environment}-bronze"
  url             = "abfss://bronze@${azurerm_storage_account.analytics.name}.dfs.core.windows.net/"
  credential_name = databricks_storage_credential.sales.id
}
# "silver" and "gold" follow the same shape
```

**Consequences.** Even though the storage credential *could* reach any
container on the account, Unity Catalog only allows managed access through
registered external locations — an extra layer of least-privilege beyond
the Azure RBAC role assignment.

---

## Unity Catalog: metastore, catalog, and schema strategy

**Context.** A Unity Catalog **metastore** is an *account-level* object in
Databricks — one per region, shared across every workspace in that region,
not something created per environment or per workspace. This is the same
bootstrap-circularity shape the existing App Registration setup already
has (`../adr/0002-*`): an account-level object can't reasonably be created
by a per-environment CI/CD pipeline run.

**Decision.**

- **Metastore** — one, created once by hand (see
  [IMPLEMENTATION.md §Bootstrap](IMPLEMENTATION.md#bootstrap)), assigned to
  each workspace via `databricks_metastore_assignment`.
- **Catalog** — one per *environment*, not one per medallion layer:
  `dev` and `prod`. This keeps environment isolation at the catalog level
  (PRD §10: "a change or failure in Development must not unintentionally
  affect Production") — a `dev`-scoped identity has no catalog-level path
  to `prod` data even if it somehow reached the `prod` workspace.
- **Schema** — one per medallion layer, inside each environment's catalog:
  `bronze`, `silver`, `gold`.

```hcl
resource "databricks_catalog" "sales" {
  name         = var.environment # "dev" or "prod"
  metastore_id = var.metastore_id
  comment      = "Sales analytics — ${var.environment}"
}

resource "databricks_schema" "bronze" {
  catalog_name = databricks_catalog.sales.name
  name         = "bronze"
  storage_root = "abfss://bronze@${azurerm_storage_account.analytics.name}.dfs.core.windows.net/"
}
# "silver" and "gold" follow the same shape, pointing at their own container
```

**Consequences.** Querying is always `dev.bronze.*` / `prod.gold.*` —
environment and layer are both explicit in every fully-qualified table
name, with no risk of a `dev` query accidentally resolving against `prod`
data.

---

## Identity model: groups, not custom roles

**Context.** PRD §6 names two distinct stakeholder groups (Sales — read
access for reporting; Data Engineering — builds and operates the platform)
and PRD §11 requires least-privilege, environment-differentiated access.
Unity Catalog has **no first-class "role" object** distinct from a group
(unlike, e.g., Snowflake's `ROLE`) — grants attach directly to a principal,
and a principal is a user, a service principal, or a group. A "custom
role" in Unity Catalog is therefore not a separate resource to create; it
*is* a named group plus the fixed set of grants applied to that group.

**Decision.** Three account-level groups per environment (six total,
`dev`/`prod` never share a group — see "Groups are environment-scoped,"
below), sourced from Entra ID and synced to the Databricks account via
SCIM (group *membership* — who's actually in `grp-sales-analysts-prod` —
is an Entra ID/HR concern, not something Terraform manages; Terraform only
references the group name as a grant principal, the same externally-
bootstrapped-identity pattern already used for `sp-terraform-*`):

| Group | Represents (PRD §6) | Layers | Privileges |
|---|---|---|---|
| `grp-sales-stakeholders-<env>` | Sales — report consumers | `gold` only | `USE_CATALOG`, `USE_SCHEMA`, `SELECT` |
| `grp-sales-analysts-<env>` | Sales — ad hoc/drill-down analysis | `silver`, `gold` | `USE_CATALOG`, `USE_SCHEMA`, `SELECT` |
| `grp-sales-data-engineers-<env>` | Data Engineering — builds/operates pipelines | `bronze`, `silver`, `gold` | `USE_CATALOG`, `USE_SCHEMA`, `SELECT`, `INSERT`, `UPDATE` (+ `DELETE` in `dev` only — see below) |
| `sp-terraform-<env>` (existing) | CI/CD automation, not a human role | all | `USE_CATALOG`, `USE_SCHEMA`, `CREATE_SCHEMA`, `CREATE_TABLE` |

`grp-sales-data-engineers-*` uses the fine-grained DML privileges
(`INSERT`/`UPDATE`/`DELETE`, least-privilege children of the composite
`MODIFY` privilege, GA on current Databricks Runtime) instead of blanket
`MODIFY` — a pipeline identity that only ever appends new bronze data
doesn't need delete rights just because it needs write rights.

Stakeholders don't get `bronze`/`silver` access at all — they're raw and
intermediate layers, not meant for direct business consumption; PRD §7's
"analytical datasets should be designed around business questions, not
either source system's schema" is exactly what `gold` exists to provide.
Analysts sit one step wider than stakeholders (add `silver`, for
investigating a number back toward its inputs) but still never touch
`bronze` directly, and never get write access — only
`grp-sales-data-engineers-*` and `sp-terraform-*` write anything.

**Groups are environment-scoped — no group spans `dev` and `prod`.**
`grp-sales-data-engineers-dev` and `grp-sales-data-engineers-prod` are two
separate groups, not one group granted on two catalogs: this is what makes
PRD §11's "Production access should be more restricted than Development
access" an enforceable, differentiated grant instead of a sentence nobody
checks —

```hcl
resource "databricks_grants" "dev_catalog" {
  catalog = databricks_catalog.sales.name # "dev"

  grant {
    principal  = "grp-sales-data-engineers-dev"
    privileges = ["USE_CATALOG", "USE_SCHEMA", "SELECT", "INSERT", "UPDATE", "DELETE"]
  }
  # grp-sales-analysts-dev, grp-sales-stakeholders-dev, sp-terraform-dev follow the table above
}

resource "databricks_grants" "prod_catalog" {
  catalog = databricks_catalog.sales.name # "prod"

  grant {
    principal  = "grp-sales-data-engineers-prod"
    privileges = ["USE_CATALOG", "USE_SCHEMA", "SELECT", "INSERT", "UPDATE"] # no DELETE in prod
  }
  # grp-sales-analysts-prod, grp-sales-stakeholders-prod, sp-terraform-prod follow the table above
}
```

**Consequences.** Because Unity Catalog privileges inherit downward
(catalog → schema → table, present *and future* — `../ARCHITECTURE.md`'s
"future-phase" framing applies directly here), granting once at catalog
level covers every table the pipeline creates later; nobody has to remember
to re-grant per table. A person moving from Development to a
Sales-analyst role in Production is an Entra ID group-membership change,
not a Terraform change — but a person's *capabilities* differ by
environment because the groups themselves, not just membership, differ.
This is the Unity Catalog-level analogue to the Azure RBAC role
assignments `../adr/0002-*` already documents for Terraform's own Azure
access — two independent least-privilege layers, neither a substitute for
the other.

---

## Terraform / Databricks Asset Bundles ownership boundary

**Context.** Databricks Asset Bundles (DABs) are the standard tool for
deploying *workspace* artifacts — jobs, pipelines, notebooks — once a
future phase actually builds the sales pipeline this platform's
infrastructure supports. DABs and Terraform can both technically express
Unity Catalog grants and workspace-object permissions, and `databricks_grants`
is **authoritative**: every Terraform apply overwrites the *entire* grant
set on a securable, silently reverting anything changed out-of-band —
including a grant a DAB `databricks.yml` declared. Separately, `bundle
validate` itself warns when a bundle's own `permissions:` block (which
controls `CAN_MANAGE` on the *job/pipeline object*, not on data — a
different Unity Catalog concept, more workspace-ACL-like) doesn't
explicitly include the deploying identity, since DAB has no visibility
into Terraform-side RBAC and can't reconcile against it. A third
overlap point: DABs also has its own first-class `volumes` resource type
(`resources: volumes:` in `databricks.yml`) — the bronze external volume
this platform needs for Auto Loader/file-arrival ingestion (see "Unity
Catalog: external locations" above) could, in principle, be declared by
either tool.

**Decision.** Three independent surfaces, one owner each, never
overlapping:

- **Unity Catalog data grants** (`databricks_grants` on catalogs, schemas,
  tables) — **Terraform-owned only.** A future pipeline's `databricks.yml`
  must never declare a `grant`/permissions block targeting a catalog or
  schema this repo already provisions.
- **Shared Unity Catalog objects that wrap infrastructure this repo
  provisions** — catalogs, schemas, external locations, and the bronze
  ingestion **volume** — **Terraform-owned only**, the same rule as
  grants, for the same reason: these sit directly on top of the storage
  account/containers Terraform already creates, and any future pipeline
  needs to reference *the same* volume by name rather than each defining
  its own competing copy. A future `databricks.yml` references
  `sales_bronze_landing` (or whatever this repo names it) as an
  already-existing volume, never declares its own `resources: volumes:`
  entry for it.
- **Workspace object permissions** (who can view/run/manage a specific
  job or pipeline — DAB's own `permissions:` block, or the Terraform
  `databricks_permissions` resource) — **DAB-owned**, since that's scoped
  to artifacts DABs itself deploys; Terraform never creates jobs/pipelines
  in this design, so there's nothing for it to compete over here.

**Consequences.** The dividing line in every case is the same test: an
object is Terraform's if it's shared, foundational, and would need to
outlive or be referenced by more than one future pipeline; it's DAB's if
it's specific to one pipeline's own implementation (its jobs, its
notebooks, a scratch/working volume only that pipeline uses for its own
checkpoints or temp state — as opposed to the shared landing volume). When
the pipeline phase starts, its `databricks.yml` should reference this
platform's catalogs/schemas/volumes by **name only** (as objects that
already exist, created by this repo) and must not attempt to declare,
grant, or revoke anything on them — and its own `permissions:` block
should explicitly list the deploying identity (its own CI/CD service
principal, likely a *different* SP than `sp-terraform-*`, scoped to the
workspace rather than to Azure resources) to avoid exactly the `bundle
validate` warning this decision was prompted by.

---

## CI/CD architecture

**Context.** The existing pipeline (`../ARCHITECTURE.md` §3,
`../adr/0002-*`) already implements: `fmt-check` → `plan-dev` (PR comment)
→ `apply-dev` (auto, on merge) → `plan-prod` → `apply-prod` (gated by the
`production` GitHub Environment's required reviewer) → a manual `sandbox`
`workflow_dispatch` job.

**Decision.** All resources above are added as new `module` blocks inside
the *existing* `environments/dev`/`environments/prod` root modules (see
[IMPLEMENTATION.md](IMPLEMENTATION.md)) — no new jobs, no new gates. The
`databricks` provider's own authentication (see
[IMPLEMENTATION.md](IMPLEMENTATION.md)) reuses each root's existing OIDC
identity wherever the provider supports it.

**Consequences.** The existing destructive-change detection
(`../adr/0002-*`, "Destructive change detection") applies to every
resource above exactly as it does to storage/budget resources today.

---

## Networking — deferred to backlog

**Context.** [PRD.md §5 / §16](PRD.md) explicitly place detailed network
architecture out of scope unless required to provision the initial
platform.

**Decision.** No private endpoints, no VNet injection via
`azurerm_databricks_workspace`'s `custom_parameters` block, no network
security groups. The workspace and storage account remain on their default
public-network configuration, matching the existing storage account's
current configuration.

**Consequences.** Explicit, documented gap, not an oversight — revisit if a
real networking requirement emerges (compliance, private connectivity to
on-prem systems), at which point it becomes its own ADR given the scope of
change involved (analogous to `../adr/0001-*`'s treatment of the sandbox
subscription-scope gap).

---

## Reproducibility summary

```text
                Version Control
                       │
                       ▼
                    Terraform
                       │
              ┌────────┴────────┐
              ▼                 ▼
             DEV               PROD
              │                 │
   rg-analytics-dev-neu-01   rg-analytics-prod-neu-01
              │                 │
      Databricks workspace  Databricks workspace
      + access connector    + access connector
              │                 │
        catalog: dev        catalog: prod
      schemas: bronze/      schemas: bronze/
       silver/gold           silver/gold
              │                 │
     bronze/ lifecycle:    bronze/ lifecycle:
     cool@90d, archive@1y,  cool@90d, archive@1y,
        delete@5y              delete@5y
```

Nothing here introduces a new Terraform root, a new backend, or a new
CI/CD job — the reproducibility and isolation properties already
established by `../adr/0002-*` extend to this platform's resources without
modification.
