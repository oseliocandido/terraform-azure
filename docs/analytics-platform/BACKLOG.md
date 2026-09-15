# Backlog — Retail Sales Analytics Platform

Items discussed and reasoned through during design, but deliberately not
part of the initial implementation — either because they're genuinely
future-phase (a later pipeline's concern), or because they're a real gap
identified during design that needs its own decision before it can be
implemented. This is distinct from
[IMPLEMENTATION.md's "Open questions to resolve before implementation
starts"](IMPLEMENTATION.md#open-questions-to-resolve-before-implementation-starts) —
those block the *already-decided* scope below from being built; this file
tracks scope not yet decided at all.

---

## Accepted risk: single-root-module `terraform destroy` ordering

**Context.** `environments/dev`'s `provider "databricks"` block is
configured from `module.databricks_workspace.workspace_url` — a computed
attribute of a resource (`azurerm_databricks_workspace`) created in the
*same* apply, not a `data` source. This is a known-risky pattern:
Terraform's own documented recommendation (and standard practice for any
provider configured from a resource you also create — the same issue
applies to Kubernetes, PostgreSQL, Vault providers) is to split into two
root modules, one creating the platform resource, a second reading it via
a `data` source so the provider can always be configured, including
during destroy.

**The concrete failure mode, if ever hit**: `terraform destroy` walks the
resource graph in reverse, but Terraform doesn't model provider
configuration as a graph node the way it would need to guarantee correct
ordering here. In practice, the workspace can be destroyed while
`databricks_*` objects (catalog, schemas, external locations, storage
credential) are still in state — at which point the provider can no
longer resolve `workspace_url` at all, so those objects can't be deleted
through Terraform. They're left as orphaned state entries, recoverable
only via manual `terraform state rm` for each one, followed by a second
`destroy` for the now-unblocked Azure resources.

**Decision: accepted for now, not fixed.** A full `terraform destroy` of
`dev` isn't currently planned, and splitting into two root modules (a
platform root creating the workspace, a databricks-contents root reading
it via `data "azurerm_databricks_workspace"`) is a real, non-trivial
restructure — comparable in scope to the `modules/unity_catalog`
consolidation already done this session. Revisit when either becomes
true: `prod` is being built (worth getting the pattern right before
duplicating the current structure a second time), or a real destroy of
`dev` becomes a routine/likely operation rather than a hypothetical one.

---

## Identity: group provisioning status

Every `grp-*` principal referenced anywhere in this repo is an Entra ID
group, created via `az ad group create` and then registered at the
Databricks account level by hand (Account Console → User management →
Groups → Add group) — Automatic Identity Management syncs an *existing*
account-level group's membership continuously, but registering a group
at the account level in the first place is still a one-time manual step,
outside Terraform's scope. Status as of this session:

| Group | Status | Needed for |
|---|---|---|
| `grp-databricks-account-admins` (account-level, one, not per-env) | Provisioned, member confirmed | `owner` on `databricks_metastore.primary` |
| `grp-sales-data-governance-dev` | Provisioned | `owner` on `sales_dev`'s catalog/schemas/storage credential |
| `grp-sales-data-governance-prod` | **Not yet provisioned** | `owner` on `sales_prod`'s catalog/schemas/storage credential — blocks `terraform apply` on `prod` once its `unity_catalog` module actually runs |
| `grp-sales-stakeholders-<env>`, `grp-sales-analysts-<env>`, `grp-sales-data-engineers-<env>` (dev + prod, 6 total) | Provisioned | `databricks_grants` once `enable_grants = true` |
| `grp-databricks-ci-dev` / `grp-databricks-ci-prod` (Entra ID groups, `sp-terraform-dev`/`-prod` added as members) | **Not yet registered at the Databricks account level** | Workspace membership (`databricks_permission_assignment`) and metastore `CREATE_*` privileges (`databricks_grants.metastore_admins`) for the CI service principals — see `environments/dev/main.tf`/`environments/prod/main.tf`'s `ci_group` resources |

**Remaining action needed, outside Terraform:** register
`grp-sales-data-governance-prod`, `grp-databricks-ci-dev`, and
`grp-databricks-ci-prod` at the Databricks account level, then flip
`enable_grants = true` when ready for the data-layer grants too.

---

## Compute / cluster architecture — not yet specified

**Gap.** Neither [ARCHITECTURE.md](ARCHITECTURE.md) nor
[IMPLEMENTATION.md](IMPLEMENTATION.md) specifies any compute resource
(cluster, SQL warehouse, or serverless) or its workspace-level ACL.
Unity Catalog grants and workspace compute permissions are two
independent systems — a user with full `SELECT` on `prod.gold` still
needs `CAN_ATTACH_TO` on *some* compute resource in the `prod` workspace
to run a query at all, and nothing in this repo currently provisions or
scopes that resource. The provider resource for this, once the decisions
below are made, is `databricks_permissions` (`cluster_id`/`sql_endpoint_id`
+ `access_control` blocks per group) — same `grp-sales-*-<env>` groups
already defined in ARCHITECTURE.md's "Identity model," just granting
compute-attach instead of data grants.

**Also blocking this:** no capacity/throughput sizing study exists yet —
PRD.md §3 deliberately no longer states a store-count or
transactions-per-day target, since no analysis backs those numbers. Any
future cluster-sizing decision needs that study done first, not a
retrofit against a figure nobody validated.

**What needs deciding, before this becomes an ARCHITECTURE.md section:**

- Serverless SQL warehouses (simplest — fully managed, always
  Unity-Catalog-enforced by design, no cluster access-mode complexity) vs.
  provisioned clusters.
- If provisioned clusters: access mode (standard/shared vs.
  dedicated/single-user — only these two can reach Unity Catalog data at
  all), minimum Databricks Runtime version (dedicated/single-user needs
  15.4 LTS+ for full fine-grained access control).
- Whether to use **dedicated compute group access** (a cluster dedicated
  to one of the groups already defined in ARCHITECTURE.md's "Identity
  model" section, e.g. `grp-sales-data-engineers-dev`) so compute-attach
  rights and Unity Catalog data grants are aligned by design instead of
  managed as two disconnected decisions.
- Workspace-level ACLs (`CAN_ATTACH_TO`/`CAN_RESTART`/`CAN_MANAGE`) per
  group, per environment — likely a new `databricks_permissions` resource
  once a compute resource exists to attach the ACL to.

---

## Bronze ingestion: file-driven triggering (Auto Loader / file events)

**Context.** Discussed at length: new files landing in `bronze` (from the
POS/e-commerce systems, per PRD §2) should trigger ingestion
asynchronously rather than relying on polling. Two real mechanisms exist,
not yet chosen or written into ARCHITECTURE.md as a decision:

- **Auto Loader, file notification mode** — Event Grid + Azure Queue
  Storage wired manually (or Auto Loader-provisioned), with three extra
  RBAC roles needed on the access connector's managed identity
  (`Contributor`, `Storage Queue Data Contributor`,
  `EventGrid EventSubscription Contributor`). Not supported on Premium
  storage accounts (ours is Standard, so not a blocker).
- **Managed file events on the external location** (the more modern
  approach) — `enable_file_events = true` + a `file_event_queue` block on
  `databricks_external_location.bronze`; on Azure this still requires a
  provided Azure Queue Storage queue (`provided_aqs`), it isn't fully
  hands-off the way AWS/GCP's managed queues are.
- **Databricks Jobs' file arrival trigger** — separate from Auto Loader
  entirely; a Job trigger type that fires a run when files land at a
  registered external location/volume, without a permanent streaming
  cluster. Likely the better fit for "simple workflow jobs triggered by
  async notification" once a pipeline exists — but the job itself is
  pipeline scope (per the Terraform/DAB ownership boundary already
  written into ARCHITECTURE.md), so only the *capability* (the external
  location's file-events configuration, the queue, the RBAC) belongs to
  this repo.

**Why deferred.** Enabling this is infra, but there's no consumer for it
yet — no job, no pipeline — until the data-pipeline phase (explicitly out
of scope per [PRD.md §16](PRD.md#data-pipelines)) actually exists.
Revisit when that phase starts; add as a new ARCHITECTURE.md
Context/Decision/Consequences section at that point, likely appended to
"Unity Catalog: external locations."

**Scoping note for whenever this is picked up.** `modules/unity_catalog`'s
`databricks_external_location.bronze` covers the *entire* bronze
container — not just the landing zone. That location also backs the
`bronze` schema's own `storage_root`, so it covers the schema's internal
`__unitystorage/schemas/<id>/tables/<id>/` managed-table writes too.
Enabling `enable_file_events` there as-is would track change
notifications for that internal Delta churn as well as genuine external
file drops — not useful, since nothing downstream should be reacting to
Delta's own writes. The precise design: a **second, narrower external
location** scoped just to `bronze/landing/` (the same subpath
`databricks_volume.sales_bronze_landing` already sits on), with
`enable_file_events` on *that* one only, leaving the broad bronze
location's file events off. Currently `enable_file_events = false` on
both (see `modules/unity_catalog/main.tf`'s comment) — correct for now,
since neither has a consumer yet either way.

---

## Bronze landing: per-source-system external volumes

**Context.** PRD §2/§13 names exactly two source systems feeding this
platform — the point-of-sale system (physical stores) and the
e-commerce platform — "each system has a different schema and update
frequency" (PRD §2). Today, `bronze` is one undifferentiated container
with a single external location
(`databricks_external_location.bronze`, covering the whole container
root) and a single landing volume
(`databricks_volume.sales_bronze_landing` — see "Ingestion landing:
`databricks_volume`" above). Nothing in the current design
distinguishes POS files from e-commerce files once they're in `bronze`,
and nothing scopes access separately per source system.

**Gap, per Databricks' Unity Catalog best practices.** The doc is
explicit on two points this project doesn't yet implement:
"use external volumes for landing areas, staging locations, and
unstructured data access" (plural — one per landing area, not one
shared catch-all), and "avoid granting general `READ FILES` or
`WRITE FILES` permissions to end users" — broad file-level access at
the external-location grain is exactly the shape to avoid; access
belongs at the volume grain, scoped to the identity that needs it.

**The shape this implies, once a real pipeline exists:**

- Two external volumes instead of one — `bronze.pos_landing` and
  `bronze.ecommerce_landing` — each backed by its own subfolder
  (`bronze/pos/landing/`, `bronze/ecommerce/landing/`), not the single
  shared `bronze/landing/` path `sales_bronze_landing` currently uses.
  Same narrowing principle as the external-location scoping note above,
  just carried one level further: per source system, not just
  per-landing-zone-vs-whole-container.
  A concrete failure this prevents: an e-commerce ingestion bug that
  lists/reads its own landing folder recursively can't accidentally
  enumerate or read POS files sitting in a sibling folder it was never
  granted `READ VOLUME` on — with one shared volume today, both source
  systems' files sit under the same grantable object, so nothing
  Unity-Catalog-enforced stops that.
- Grants scoped per volume: `READ VOLUME`/`WRITE VOLUME` on
  `bronze.pos_landing` to whatever identity owns POS ingestion,
  `READ VOLUME`/`WRITE VOLUME` on `bronze.ecommerce_landing` to whatever
  identity owns e-commerce ingestion — not a blanket grant on the whole
  bronze external location, and not human/`grp-sales-data-engineers-*`
  access to either (per the pipeline-writes-not-humans reasoning already
  documented for the catalog-level `INSERT`/`UPDATE` grant in
  ARCHITECTURE.md's Identity model section).
- `databricks_volume.sales_bronze_landing` (today's single volume) would
  need to be replaced by these two, not kept alongside them — one
  shared landing volume and two source-scoped ones would just
  reintroduce the same overlap problem at a smaller scale.

**Why deferred, not built now.** The ingestion identities that would
hold these per-volume grants don't exist yet — same dependency as
"Pipeline-phase bootstrap" below (a pipeline-phase service principal,
likely one per source system rather than one shared SP, given the
whole point is that a POS ingestion bug shouldn't be able to touch
e-commerce files). Revisit together with that item and the file-events
scoping note above — all three are the same underlying "narrow bronze
past the container root" work, just at different grains, and are
cheapest to design once as a single ARCHITECTURE.md section rather than
three separate retrofits.

---

## Silver/gold retention and VACUUM

**Context.** The current `azurerm_storage_management_policy` only covers
`bronze/` (see ARCHITECTURE.md's "Data retention and lifecycle policy") —
deliberately, since `silver`/`gold` are derived/rebuildable and mutable
(subject to `UPDATE`/`MERGE`, unlike bronze's append-only shape), so a
blob-age lifecycle rule risks deleting a file a live Delta table's
transaction log still references.

**Not yet decided:**

- Whether `silver`/`gold` ever get their own (shorter, or absent) lifecycle
  rule once they have real data volume.
- `VACUUM` retention tuning — a *pipeline-operational* concern (default
  7-day/168-hour retention, whoever builds the pipeline schedules it), not
  an infrastructure resource this repo provisions, but worth a one-line
  cross-reference in ARCHITECTURE.md so a future reader doesn't conflate
  it with the blob lifecycle policy.

---

## Ingestion landing: `databricks_volume` (external, bronze) — done

**Done, `dev`.** `databricks_volume.sales_bronze_landing` — see
[IMPLEMENTATION.md](IMPLEMENTATION.md#databricks_volume--bronze-ingestion-landing-backlogmd)
for the resource and the storage-path constraint found while building it.
Not yet built for `prod`, since `prod` itself doesn't exist yet.

---

## Pipeline-phase bootstrap (Databricks Asset Bundles)

**Context.** ARCHITECTURE.md's ownership-boundary decision assumes the
future pipeline's `databricks.yml` deploys under "its own CI/CD service
principal, likely a *different* SP than `sp-terraform-*`, scoped to the
workspace rather than to Azure resources" — that SP doesn't exist yet,
and its bootstrap (App Registration, federated credential, workspace-level
permissions — not Azure RBAC, since it never touches ARM) isn't recorded
anywhere. Deferred until the pipeline phase actually starts; will likely
follow the same one-time-`az`-CLI bootstrap pattern already used for
`sp-terraform-*` (`docs/azure-setup-commands.sh`).

**Also deferred to that point:** a fifth, pipeline-specific SP alongside
whatever `grp-sales-*` groups exist by then — see "Identity: group
provisioning status" above for what's still outstanding; that item isn't
pipeline-phase-specific and shouldn't wait for this one.

---

## Networking (tracked here for visibility, decision already recorded)

Already has a full decision in
[ARCHITECTURE.md's "Networking — deferred to backlog"](ARCHITECTURE.md#networking--deferred-to-backlog)
and [PRD.md §16](PRD.md#networking) — listed here only so this file is a
complete index of open scope, not because the decision itself is unmade.
