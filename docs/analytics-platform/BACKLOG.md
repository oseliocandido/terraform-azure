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
| `grp-sales-data-governance-dev` | Provisioned | `owner` on `sales_dev`'s catalog/schemas (bare-string reference, not a data-source lookup -- see below). No workspace-level permission, deliberately |
| `grp-sales-data-governance-prod` | **Not yet provisioned** | `owner` on `sales_prod`'s catalog/schemas — blocks `terraform apply` on `prod` once its `unity_catalog` module actually runs |
| `grp-sales-stakeholders-<env>`, `grp-sales-analysts-<env>`, `grp-sales-data-engineers-<env>` (dev + prod, 6 total) | Provisioned | `databricks_grants` once `enable_grants = true` (flipped for `dev` in `environments/dev/terraform.tfvars`) |
| `grp-databricks-ci-dev` / `grp-databricks-ci-prod` (Entra ID groups, `sp-terraform-dev`/`-prod` added as members) | `-dev` registered and applied; `-prod` registered, not yet applied (`prod` itself doesn't exist) | Workspace membership (`databricks_permission_assignment`) and metastore `CREATE_*` privileges (`databricks_grants.metastore_admins`) for the CI service principals — see `environments/dev/main.tf`/`environments/prod/main.tf`'s `ci_group` resources |
| `grp-databricks-platform-dev` / `grp-databricks-platform-prod` (Entra ID groups; `oseliocandido` added to `-dev` for bootstrap) | Registered | `owner` on `databricks_storage_credential.analytics` and the bronze/landing external locations (bare-string reference -- see below). No workspace-level permission, deliberately |
| `grp-marketing-data-governance-<env>`, `grp-marketing-stakeholders-<env>`, `grp-marketing-analysts-<env>`, `grp-marketing-data-engineers-<env>` (dev + prod, 8 total) | Created in Entra ID (`docs/azure-setup-commands.sh` step 10); **not yet registered at the Databricks account level** | Same roles as their `grp-sales-*` counterparts, for the second domain (`module.unity_catalog_marketing` in `environments/dev/main.tf`/`environments/prod/main.tf`). `module.unity_catalog_marketing`'s `enable_grants` is a literal `false` (not wired to `var.enable_grants`, unlike `unity_catalog_sales`) specifically so flipping `dev`'s `var.enable_grants` for sales' own now-provisioned groups can't accidentally also try to grant to marketing's groups before they exist |

**Only `grp-databricks-ci-<env>` needs workspace-level presence.**
An earlier version also gave `grp-databricks-platform-<env>` and
`grp-sales-data-governance-<env>` workspace membership + the
`workspace_access` entitlement, purely as a side effect of using
`data "databricks_group"` lookups for their `owner =` references (a
workspace-scoped lookup requires the looked-up group to already be a
workspace member to resolve). Neither group actually operates in the
workspace -- they're pure Unity Catalog ownership/governance, enforced by
UC itself independent of workspace membership. Switched both to bare
string `owner` references instead (losing the "fails clearly at plan
time if the group doesn't exist" diagnostic for these two specifically,
in exchange for not granting workspace access to groups with no
operational need for it) and removed their `databricks_permission_
assignment`/`databricks_entitlements` resources entirely. This also
resolved a real drift found via the Account Console: `grp-sales-data-
governance-dev` had a manual, non-Terraform-tracked workspace `Admin`
grant (presumably added by hand mid-session to unblock something) --
confirmed gone after this cleanup (checked directly against the account's
own SCIM API).

**`dev` is fully applied** as of this session, including the catalog-level
grant that was blocked earlier by this metastore's privilege version:
`grp-sales-data-engineers-<env>`'s catalog grant is blanket `MODIFY`, not
the fine-grained `INSERT`/`UPDATE`/`DELETE` split an earlier version used
(this metastore's privilege version `1.0` doesn't support fine-grained
DML privileges at the catalog level -- confirmed via `terraform apply`
error, `Privilege UPDATE is not applicable to this entity
[CATALOG/CATALOG_STANDARD]`; no dev/prod `DELETE` distinction is possible
on this metastore version either way). `sales_dev` catalog, all three
schemas, the storage credential, bronze/managed/landing external
locations, all catalog/schema-level grants, and both landing volumes'
grants all exist for real in Databricks now, not just planned. `prod`
still doesn't exist at all (no workspace, no catalog);
`grp-sales-data-governance-prod` is the only remaining un-registered
group, and registering it is what unblocks `prod`'s first apply.

**Marketing added as a real second domain (2026-09-16)**, which surfaced
two bugs `modules/databricks/unity_catalog` had carried since it only
ever had one caller: the module's own resources (`databricks_catalog`,
`databricks_workspace_binding`, `databricks_grants`) were labeled `sales`
regardless of `var.domain`, and worse, every grant principal inside it
(`grp-sales-stakeholders-<env>`, `grp-sales-analysts-<env>`,
`grp-sales-data-engineers-<env>`, and the `data_governance_group_name`
local) was a literal `sales` string too -- calling the module with
`domain = "marketing"` would have owned/granted `marketing_dev` to sales'
own groups. Fixed by parameterizing all of it on `var.domain`, renaming
the resources off the `sales` label (`moved` blocks protect `dev`'s
already-applied state -- confirmed `0 to destroy` on replan), and
splitting the root's own module call into `unity_catalog_sales` /
`unity_catalog_marketing` (also `moved`-protected). Separately,
`modules/analytics`'s single shared `managed` container couldn't back a
second catalog's `storage_root` either -- Unity Catalog rejects
overlapping external-location registrations, and `sales_dev`'s already
claims the whole container. Rather than migrate `sales`'s already-applied
storage root to a subpath (real risk, `azurerm_storage_container.name` is
ForceNew), added `var.additional_domains` and a `managed-<domain>`
container per entry, leaving the original `managed` container/domain
untouched. `unity_catalog_marketing.enable_grants` stays a literal
`false` until the `grp-marketing-*` groups above are provisioned -- see
the table above.

**Bronze/landing moved to a dedicated `ingestion_<env>` catalog, out of
the domain catalogs entirely (2026-09-16).** Marketing exposed a second
bug beyond the group-hardcoding one above: `unity_catalog`'s `bronze`
schema was created unconditionally per domain, so `sales_dev.bronze` and
`marketing_dev.bronze` would have been two separate Unity Catalog schema
objects both pointing at the identical physical bronze container --
bronze was never actually domain-specific data (it's raw POS/e-commerce
files), so creating it per domain just duplicated the same source data's
UC registration once per catalog that happened to call the module.
Fixed by removing `databricks_schema.bronze` (and `var.
bronze_external_location_url`) from `modules/databricks/unity_catalog`
entirely, and adding a new, non-domain `ingestion_<env>` catalog to
`modules/databricks/storage` (owned by
`grp-databricks-platform-<env>`, which already administered this
infrastructure one layer down) holding `bronze` plus the `pos_landing`/
`ecommerce_landing` volumes and their new `pos_landing_checkpoint`/
`ecommerce_landing_checkpoint` companions (Auto Loader checkpoint/schema-
evolution state -- Databricks explicitly recommends this live in UC-
managed storage, separate from the source files being ingested, and UC
itself disallows nesting checkpoint files under the ingested-table
directory anyway). A domain that needs bronze access now gets an
explicit grant on `ingestion_<env>.bronze` (`bronze_consumer_group_name`,
currently `grp-sales-data-engineers-<env>` only -- no second domain has a
real, PRD-backed need for this raw feed yet) instead of inheriting it
automatically from its own catalog-level grant. `dev`'s already-applied
`pos_landing`/`ecommerce_landing` volumes and `sales_dev.bronze` schema
get destroyed/recreated in the new catalog on next apply -- confirmed
safe: both were external-storage-backed (bronze's own `storage_root`,
each volume's `storage_location`), so dropping the old UC registrations
never touches the underlying blob files, same reasoning as any other
`EXTERNAL` volume/location drop in this codebase. The two checkpoint
volumes still have no `databricks_grants` -- same "no dedicated pipeline
service principal yet" gap as before, just relocated along with the
volumes themselves.

**Domain-level `bronze` schema restored, immediately after removing it
above (2026-09-16)** -- turned out the removal was half right, not fully
wrong. `ingestion_<env>.bronze` genuinely needed to be the ONE place raw
landed files get registered (that part of the fix stands). But each
domain also needs its own `bronze` schema back:  data engineers decide
*downstream of ingestion*, not at landing time, whether a given raw
record belongs to `sales` or `marketing`, and that curated/routed result
needs its own domain-owned home. The two aren't the same object this
time, so it isn't the original bug again: the old, removed schema pointed
`storage_root` at the shared RAW landing container (the actual bug); this
one is `MANAGED` -- no `storage_root` at all, same shape as `silver`/
`gold` -- physically stored under each domain's own managed container,
populated by a pipeline write, not a second registration against
ingestion's raw files. `sales_dev.bronze` (already applied, currently
empty) will show as replaced, not a bare destroy, on the next `dev` plan
-- safe, since it never held real data.

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

## Bronze ingestion: file-driven triggering (Auto Loader / file events) — mostly done

**Done.** The two concerns this section used to treat as speculative are
both real now, and resolved differently than originally sketched below
(kept for context, not because the original plan is what got built):

- **Per-source-system landing, not one shared container.** Superseded the
  "second narrower external location scoped to `bronze/landing/`" idea
  entirely — instead of subpath-scoping one bronze location, POS and
  e-commerce each got their own dedicated Azure container and their own
  `databricks_external_location` (`pos_landing`/`ecommerce_landing` in
  `modules/databricks/storage/main.tf`), each with
  `enable_file_events = true` and its own `file_event_queue { managed_aqs
  {...} }`. The raw, undifferentiated `bronze` external location
  (`modules/databricks/storage/main.tf`'s
  `databricks_external_location.bronze`) still exists and still has
  `enable_file_events = false`, and still should stay off — the reasoning
  in that resource's own comment (it covers the whole container,
  including every domain's own internal `__unitystorage/...` churn) is
  unchanged, it just now lives in `ingestion_<env>` rather than one
  shared per-catalog bronze.
- **Per-source-system volumes**, `pos_landing`/`ecommerce_landing`
  (`databricks_volume`, `EXTERNAL`), registered under
  `ingestion_<env>.bronze` — see "Ingestion catalog and domain bronze,
  restructured" further down for the fuller story of how that catalog
  came to exist. Each is `READ VOLUME`-only for
  `bronze_consumer_group_name` (currently `grp-sales-data-engineers-dev`
  only), gated by `enable_grants` — never `WRITE`, since these are
  written by the source systems directly via Azure RBAC, outside Unity
  Catalog entirely.
- **Auto Loader checkpoint/schema-evolution volumes**,
  `pos_landing_checkpoint`/`ecommerce_landing_checkpoint` (`MANAGED`, same
  module) — added after realizing checkpoints can't live inside the
  landing volumes themselves (Databricks: *"does not allow you to nest
  checkpoint or schema inference and evolution files under the table
  directory"*; separately, the landing volumes are read-only by design
  regardless). No `databricks_grants` on these two yet — no dedicated
  pipeline identity exists to grant `READ VOLUME`/`WRITE VOLUME` to (see
  "Pipeline-phase bootstrap" below).

**Still not done — the actual trigger/consumer.** Nothing in this repo
yet *reacts* to a file landing — no Databricks Job, no Auto Loader
stream, no DLT pipeline. That's explicitly out of scope per
[PRD.md §16](PRD.md#data-pipelines) and belongs to whatever picks up
"Pipeline-phase bootstrap" below. **Databricks Jobs' file arrival
trigger** (a Job trigger type that fires on new files at a registered
external location/volume, no permanent streaming cluster needed) is
still the likely fit once that phase starts — the infra capability
(external locations, file events, the queues) is what this repo already
built; the Job/pipeline itself is pipeline-repo scope per
ARCHITECTURE.md's Terraform/DAB ownership boundary.

---

## Bronze/silver/gold retention and VACUUM

**Context (corrected 2026-09-16).** The `azurerm_storage_management_policy`
now covers `landing-pos/`/`landing-ecommerce/` only, not `bronze` (see
ARCHITECTURE.md's "Data retention and lifecycle policy") — an earlier
version of this policy targeted `bronze/` instead, reasoned as safe because
bronze is append-only unlike silver/gold's `UPDATE`/`MERGE` shape. That
reasoning had it backwards: mutation pattern isn't what makes a blob-age
lifecycle rule unsafe for a Delta table — *being a Delta table at all* is.
An append-only table's data files stay referenced by the current snapshot
indefinitely (nothing ever tombstones them the way `MERGE`/`UPDATE` does),
so a blob-lifecycle rule deleting one by age is deleting live, currently-
referenced data with zero Delta awareness — arguably worse than doing the
same to silver/gold, not safer. Landing is the only container actually
safe for this: plain files, no transaction log, nothing to keep consistent.

**Not yet decided / not yet built — real pipeline work, tracked here so it
doesn't get conflated with the (now landing-only) blob lifecycle policy:**

- PRD §9's "remain queryable at lower cost" half of the five-year
  requirement isn't satisfied by the landing-only blob policy at all — it
  describes bronze/silver's own Delta data, not raw landing files. Needs a
  Delta-native mechanism once a pipeline exists: `VACUUM` retention tuning
  (`delta.deletedFileRetentionDuration`/`delta.logRetentionDuration`,
  default 7-day/30-day), and/or a partition-based archival job for the
  actual multi-year cost-tiering PRD §9 asks for — none of which is an
  infrastructure resource this repo provisions.
- Whether `silver`/`gold` (and now `bronze`) ever need any lifecycle
  handling beyond that once real data volume exists.

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

**Checked and ruled out (2026-09-16):** a throwaway workspace deployed to
verify Databricks' managed-resource-group provisioning (see
`modules/databricks/workspaces/main.tf`'s own SKU comment)
raised two questions that turned out to be non-issues once checked against
the real `dev` workspace and the `azurerm_databricks_workspace` docs:
- SKU: this project has used `premium` since commit `00c3380` (Unity
  Catalog requires it; Standard is being retired for new workspaces
  anyway) — nothing to change.
- `enableNoPublicIp` vs. `public_network_access_enabled`: these are two
  different azurerm fields, not a drift between our config and Azure's
  default. `public_network_access_enabled` (workspace URL reachability,
  our config leaves it at its `true` default) and `no_public_ip` (Secure
  Cluster Connectivity — no public IPs on cluster nodes, also defaults
  `true`) are both unset in this module and both match the real `dev`
  workspace's live values. No code change needed.
