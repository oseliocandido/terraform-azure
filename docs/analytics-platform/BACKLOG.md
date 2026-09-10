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

## Compute / cluster architecture — not yet specified

**Gap.** Neither [ARCHITECTURE.md](ARCHITECTURE.md) nor
[IMPLEMENTATION.md](IMPLEMENTATION.md) specifies any compute resource
(cluster, SQL warehouse, or serverless) or its workspace-level ACL.
Unity Catalog grants and workspace compute permissions are two
independent systems — a user with full `SELECT` on `prod.gold` still
needs `CAN_ATTACH_TO` on *some* compute resource in the `prod` workspace
to run a query at all, and nothing in this repo currently provisions or
scopes that resource.

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

## Ingestion landing: `databricks_volume` (external, bronze)

**Context.** ARCHITECTURE.md's Terraform/DABs boundary section already
decided *who* owns this (Terraform, since it wraps shared infrastructure)
and named it (`sales_bronze_landing`), but the actual
`databricks_volume` (`volume_type = "EXTERNAL"`) resource itself hasn't
been added to `modules/databricks_workspace` in IMPLEMENTATION.md yet —
only the `databricks_external_location` it would sit on top of.

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

**Also deferred to that point:** actually provisioning
`grp-sales-stakeholders-*`/`grp-sales-analysts-*`/`grp-sales-data-engineers-*`
in Entra ID and wiring SCIM sync to the Databricks account — ARCHITECTURE.md's
"Identity model" section designs the *grants* these groups receive, but
group creation/membership itself is an Entra ID/IT-admin action outside
Terraform's scope, not yet actioned.

---

## Networking (tracked here for visibility, decision already recorded)

Already has a full decision in
[ARCHITECTURE.md's "Networking — deferred to backlog"](ARCHITECTURE.md#networking--deferred-to-backlog)
and [PRD.md §16](PRD.md#networking) — listed here only so this file is a
complete index of open scope, not because the decision itself is unmade.
