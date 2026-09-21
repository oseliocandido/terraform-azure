# Architecture — Retail Sales Analytics Platform

Overview of the Azure / Databricks / Terraform design that satisfies
[PRD.md](PRD.md). Concrete HCL, inputs, and operational mechanics are in
[IMPLEMENTATION.md](IMPLEMENTATION.md); open work is in
[BACKLOG.md](BACKLOG.md). The base repo foundation (`analytics` and
`budget_alert` modules, OIDC identity, plan/apply pipeline) is in
[`../ARCHITECTURE.md`](../ARCHITECTURE.md) and
[ADR-0002](../adr/0002-pipeline-and-identity-architecture.md).

**Scope:** infrastructure only — what must exist so a pipeline can be built.
Schema design, transformations, data quality, and orchestration are pipeline
concerns and out of scope (PRD §5).

**Status:** `dev` is applied and converged. `prod` is coded identically but
not yet applied.

## At a glance

```text
                     Terraform (environments/dev, environments/prod)
                                        │
        ┌───────────────────────────────┴───────────────────────────────┐
        ▼                                                               ▼
  rg-analytics-dev-neu-01                                  rg-analytics-prod-neu-01
  Databricks workspace + access connector                  (same shape)
  ADLS Gen2 account
   ├─ landing-pos, landing-ecommerce   raw files from source systems
   ├─ bronze                           Delta tables (raw, single copy)
   └─ managed-sales / -marketing / -ingestion   catalog storage roots
        │
  Unity Catalog (one metastore per region, shared by dev and prod)
   ├─ ingestion_dev   bronze schema + <system>_landing volumes + checkpoints volume
   ├─ sales_dev       silver, gold
   └─ marketing_dev   silver, gold

  Data flow:  source system → landing-<system> → ingestion_<env>.bronze
              → <domain>_<env>.silver → <domain>_<env>.gold
```

## Environments and isolation

- One Azure subscription; each environment has its own resource group and its
  own CI service principal with `Contributor` scoped to that group only. This
  is narrower than Azure's recommended subscription-per-environment split (the
  account tier allows one subscription). A subscription split later is a
  backend key and provider change, not a redesign.
- One Unity Catalog metastore (account-level, per region) is shared by both
  environments. Environment isolation at the data layer comes from
  workspace-bound catalogs (below), not from separate metastores.
- The metastore has its own resource group and storage, outside both
  environments, so it outlives any one workspace. Databricks' auto-created
  access connector inside a workspace's managed resource group is not used.

## Storage

One ADLS Gen2 account per environment (hierarchical namespace on, private
containers, AAD-only auth), with three kinds of container:

| Container | Purpose |
|---|---|
| `landing-<system>` | One per source system (`pos`, `ecommerce`); source systems write here directly via Azure RBAC |
| `bronze` | Storage for the raw `ingestion_<env>.bronze` schema (Delta) |
| `managed-<domain>` | Storage root of one catalog (`managed-sales`, `managed-marketing`, `managed-ingestion`) |

`silver` and `gold` have no container; they are Unity Catalog managed schemas
inside their catalog's managed root. One container per catalog keeps
Unity Catalog's external-location registrations non-overlapping and limits
blast radius.

**Retention.** A blob lifecycle policy (cool at 90 days, archive at 1 year,
delete at 5 years) applies to `landing-*` only. Bronze holds Delta tables and
a blob-age policy has no awareness of the Delta log, so it is excluded;
Delta-native retention for bronze/silver is pipeline work (BACKLOG).

**Durability.** In prod, the storage account and its containers have `prevent_destroy`, and soft delete for blobs and containers is 14 days in prod (7 elsewhere). Prod uses GZRS replication.

## Databricks workspace and storage access

- One premium workspace per environment (Unity Catalog requires premium),
  default public networking (see Networking).
- An Azure Databricks access connector (managed identity) holds
  `Storage Blob Data Contributor` on the storage account and backs a single
  storage credential per environment, `cred-analytics-<env>`. No secrets to
  rotate.

## Unity Catalog model

- **Catalogs.** One per domain per environment (`sales_dev`, `marketing_dev`),
  plus a non-domain `ingestion_<env>` catalog. Each catalog has its own
  storage root registered as an external location.
- **Schemas.** Domain catalogs have `silver` and `gold`. Bronze exists once,
  in `ingestion_<env>.bronze`: bronze is source-system-oriented raw data, so a
  per-domain bronze would duplicate it. A domain reads raw data through an
  explicit grant on `ingestion_<env>` and builds silver from it.
- **External locations.** Bronze (file events off), one per landing container
  (read-only, file events on), and one per catalog root. All use the shared
  storage credential.
- **Volumes.** In `ingestion_<env>.bronze`: an `EXTERNAL` `<system>_landing`
  volume per source system over its landing location (read access only), and one
  shared `MANAGED` `checkpoints` volume (a folder per source system) reserved
  for Auto Loader state. It is stored in the `bronze` container, because the
  schema's storage root overrides the catalog's.

### Ingestion flow

```text
source system ─(Azure RBAC write)→ landing-<system>
  → read-only external location (file events on)
  → EXTERNAL volume ingestion_<env>.bronze.<system>_landing
  → [future] Auto Loader, checkpoint in checkpoints/<system>
  → bronze Delta tables in ingestion_<env>.bronze
  → domain silver → gold
```

The Auto Loader job itself is not built (BACKLOG).

## Access control

Three independent layers are checked on every request:

1. **Workspace binding** (Unity Catalog): catalogs are `ISOLATED` and bound to
   exactly one workspace, so a catalog is hidden and unusable from any other
   workspace, even for principals with grants. Schemas and volumes inherit the
   binding. Storage credential and external locations stay `OPEN` (optional
   hardening in BACKLOG).
2. **Unity Catalog grants** (`databricks_grants`, authoritative, one resource
   per securable).
3. **Azure RBAC** on the access connector's identity.

Binding does not affect access to storage that bypasses Unity Catalog; only
RBAC does.

### Groups

Groups are sourced from Entra ID, registered at the Databricks account level,
and referenced by name. Membership is managed outside Terraform. No group
spans environments.

| Group | Role | Access |
|---|---|---|
| `grp-<domain>-stakeholders-<env>` | Report consumers | `gold` read |
| `grp-<domain>-analysts-<env>` | Ad hoc analysis | `silver`, `gold` read |
| `grp-<domain>-data-engineers-<env>` | Build and operate the domain's pipelines | `USE_CATALOG`, `USE_SCHEMA`, `SELECT`, `MODIFY` on the catalog; read on raw `ingestion_<env>` (sales only today); in dev also write on the `checkpoints` volume and `CREATE_TABLE` on the bronze schema |
| `grp-<domain>-data-governance-<env>` | Owns the domain catalog and its schemas | Ownership only, kept separate from operators |
| `grp-databricks-platform-<env>` | Owns environment-wide infrastructure | Owner of the credential, bronze/landing/ingestion locations, `ingestion_<env>` and its volumes |
| `grp-databricks-ci-<env>` | CI identity plumbing | Workspace membership and metastore `CREATE_*`; contains `sp-terraform-<env>` |
| `grp-databricks-account-admins` | Account/metastore administration | Owner of the metastore |

Every Unity Catalog object is group-owned, never person-owned or owned by the
CI identity. Owner is an administrative role, so operators and owners are
separate groups (separation of duties).

Grant scoping: privileges inherit downward, so engineers and CI get
catalog-level grants, while stakeholders and analysts get only `USE_CATALOG`
on the catalog plus schema-level grants on the layers they may see.
Engineers use blanket `MODIFY` because the metastore's privilege version
(1.0) does not support fine-grained DML privileges at catalog level.

### CI identity

CI (`sp-terraform-<env>`) is not a metastore admin. It holds explicit grants
on what it must read or create (catalogs, external locations, the credential)
because ownership by another group does not cascade. Metastore-level `CREATE_*`
grants are a one-time admin bootstrap that CI plans ignore. Details in
IMPLEMENTATION.md.

## Terraform and Databricks Asset Bundles boundary

Three surfaces, one owner each:

- **Unity Catalog grants** on catalogs, schemas, and tables: Terraform only.
- **Shared foundational objects** (catalogs, schemas, external locations,
  landing and checkpoint volumes): Terraform only. Pipelines reference them by
  name and never redeclare them.
- **Workspace object permissions** (jobs, pipelines): owned by the bundle that
  deploys them.

The test: an object is Terraform's if it is shared, foundational, and outlives
any one pipeline; it is the bundle's if it is specific to one pipeline.

## CI/CD

All resources live in the existing `environments/dev` and `environments/prod`
roots, so the existing pipeline applies: `fmt-check` → `plan-dev` → (merge)
`apply-dev` → `plan-prod` → `apply-prod` behind the `production` approval
gate. `apply-*` applies the saved plan, so a stale-plan failure is fixed by
re-running the whole workflow. `environments/shared` (the account-level
metastore) is applied by hand and has no CI coverage.

## Secrets

Everything is identity-based (OIDC for CI, managed identity for storage
access, Entra ID for users), so there are no standing secrets. If one becomes
unavoidable, it goes in a Key-Vault-backed secret scope rather than a
Databricks-native one, to keep one permission system.

## Networking

Deferred (PRD §16): no private endpoints, VNet injection, or NSGs. Public
defaults, matching the existing storage account.
