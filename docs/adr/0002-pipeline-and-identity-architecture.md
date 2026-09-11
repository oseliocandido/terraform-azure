# ADR-0002: CI/CD pipeline and identity architecture

## Status

Accepted.

## Context

This ADR consolidates the technical decisions behind how this repo is
structured, authenticated, and deployed — everything except the sandbox
subscription-scope question, which has its own record in
[ADR-0001](0001-sandbox-subscription-scope.md). See
[ARCHITECTURE.md](../ARCHITECTURE.md) for the diagrams these decisions
produced.

## Module structure

Terraform has no built-in "environment" concept. Reusability comes from
`module` blocks (`modules/analytics`, `modules/budget_alert`), and
environment separation comes purely from **directory structure + backend
state key** — `environments/dev`, `environments/prod`, and the top-level
`sandbox/` are each independent root modules with their own state file,
their own `terraform.tfvars`, and their own provider block. A module itself
has no state; only a root module (the thing you actually run `terraform
init`/`plan`/`apply` in) does.

**Alternative considered and rejected:** one root module with a single
`environment` variable and conditional logic (`count`/`for_each` gymnastics
to skip resources per environment). Rejected because it makes environments
implicitly coupled through shared state and a single plan — a `dev`-only
change could accidentally surface in a `prod` plan, and the blast radius of
one root's state file spans every environment.

## OIDC identity per environment

Each environment authenticates to Azure as its own Service Principal
(`sp-terraform-dev`, `sp-terraform-prod`, `sp-terraform-sandbox`), each with
its own Entra App Registration and its own federated identity credential.

Authentication is a two-step token exchange, not a shared secret:

1. GitHub Actions' own OIDC provider issues a short-lived, repo/run-scoped
   JWT (via the auto-injected `ACTIONS_ID_TOKEN_REQUEST_URL`/`_TOKEN` env
   vars) — Terraform's `azurerm` provider requests this itself when
   `ARM_USE_OIDC = "true"` is set; nothing else in the workflow needs to
   touch it.
2. Entra ID exchanges that JWT for a real Azure AD access token, **only**
   if the JWT's `sub` claim matches a federated credential configured on
   that specific App Registration (subject format:
   `repo:<owner>@<ownerId>/<repo>@<repoId>:ref:refs/heads/<branch>`, or
   `:environment:<name>` / `:pull_request` variants).

The GitHub-issued JWT never reaches an Azure API directly — it only ever
proves identity to Entra, which issues the token that actually talks to
Azure Resource Manager.

Three separate identities (rather than one shared identity with three sets
of variables) means a bug or leaked credential in the `dev` pipeline cannot
mint a token that authenticates as `prod` — the federated credential
subject match is per-App-Registration, not per-workflow-file.

`azure/login@v2` was removed from every job: nothing in this workflow runs
a raw `az` CLI command, so the CLI session it establishes was dead weight.
Terraform's own OIDC exchange (via `ARM_*` env vars) is independent of it
and was the thing actually doing the authenticating.

## Plan/apply decoupling

`apply-dev` and `apply-prod` never run `terraform plan` — they run
`actions/download-artifact` to fetch the exact `tfplan` binary file that
the corresponding `plan-dev`/`plan-prod` job already produced, then
`terraform apply tfplan` against that file directly. The `plan-*` job's own
step order is `init -> validate -> plan -> destructive-change check -> PR
comment/job summary -> upload artifact`.

This guarantees what a human reviewed (in the PR comment for dev, in the
job summary for prod) is bit-for-bit what gets applied — no window where
Azure state could drift between "reviewed" and "applied," and no risk of a
second `plan` silently picking up a different result (a concurrent change
elsewhere, a provider version bump between jobs).

**Alternative considered and rejected:** re-running `terraform plan` inside
`apply-*` and eyeballing that it matches. Rejected because it reintroduces
exactly the race condition artifact-based apply avoids, and doubles Azure
API calls for no benefit.

## Environments are a gate, not a secret store

GitHub's `production` Environment is attached to `apply-prod` (via
`environment: production`) purely for its required-reviewer approval gate
— the job pauses until a human clicks approve. It intentionally holds **no
secrets**. `AZURE_CLIENT_ID_PROD` lives as a repository-level secret,
visible to `plan-prod` too (which does not declare `environment:
production`, since it runs automatically and would otherwise never get
past a human-approval pause it doesn't need).

This was learned the hard way: `AZURE_CLIENT_ID_PROD` was originally scoped
only to the `production` Environment, and `plan-prod` — which needs it to
even run `terraform init` — silently received an empty string instead of
an error, because GitHub Actions doesn't fail a job for referencing a
secret it can't see; it just resolves to `""`. The fix wasn't to give
`plan-prod` the `production` Environment (that would make dev-branch plans
pause for approval too, defeating automatic PR feedback) — it was
recognizing that a `client-id` isn't actually secret material. The real
security boundary is the OIDC federated-credential subject match (only a
run from the exact repo/ref this SP trusts can exchange a token) plus
RBAC scope, not secrecy of an identifier. Repo-level exposure of
`AZURE_CLIENT_ID_*` weakens nothing; hiding it behind an Environment only
broke jobs that legitimately needed it.

## Budget scope

`modules/budget_alert` originally created an
`azurerm_consumption_budget_subscription` — a resource scoped to the whole
subscription (`/subscriptions/<id>/providers/Microsoft.Consumption/budgets/<name>`,
no resource group in the ID path). Since `dev`, `prod`, and `sandbox` all
share one subscription (see [ADR-0001](0001-sandbox-subscription-scope.md)
for why), `dev`'s applied budget and `prod`'s attempted budget were
actually racing to create *the same Azure resource* under a hardcoded name
— `prod`'s first apply failed outright.

The first fix (interpolating `environment` into the budget's `name`) only
avoided the naming collision; it didn't address the structural mismatch
between "one budget per environment" (the intent) and "one shared
subscription-scoped resource" (what the code actually created) — and it
required subscription-wide `Cost Management Contributor` RBAC on both
`sp-terraform-dev` and `sp-terraform-prod`, since a subscription-scoped
resource can't be reached by resource-group-scoped RBAC.

The actual fix: migrate to `azurerm_consumption_budget_resource_group`,
scoped by `resource_group_id` (an output from `modules/analytics`)
instead of `subscription_id`. This eliminates the collision structurally —
each environment's budget now lives inside that environment's own resource
group, so there is no shared resource for two environments to contend
over — and the existing RG-scoped Contributor role each SP already holds
is sufficient; the extra `Cost Management Contributor` subscription-level
grant is no longer required (not yet revoked as of this writing — flagged
as follow-up cleanup, low urgency since it only broadens, doesn't weaken,
existing Contributor access).

## Destructive change detection

Both `plan-dev` and `plan-prod` run a `jq` filter against
`terraform show -json tfplan`, looking for any `resource_changes[]` entry
whose `change.actions` includes `"delete"`, and surface it as a
`::warning::` CI annotation plus a formatted block (PR comment for dev, job
step summary for prod) — informational only, never gating; the job still
succeeds and the plan can still be applied.

The filter was deliberately widened from its first version, which only
matched a *same-entry* `delete`+`create` pair (Terraform's usual
representation of an in-place force-replace, e.g. a `ForceNew` attribute
change). That version missed a real case: migrating
`modules/budget_alert` from `azurerm_consumption_budget_subscription` to
`azurerm_consumption_budget_resource_group` is a resource **type** change,
which Terraform represents as two *separate* `resource_changes` entries —
one `delete` on the old address, one `create` on a new, differently-typed
address — neither entry carries both actions. Confirmed by grepping the
actual `terraform show -json` output for that migration's plan. The
widened filter (`select(.change.actions | index("delete"))`, matching any
delete at all, regardless of whether a same-entry create accompanies it)
catches both cases at the cost of also flagging plain deletions — treated
as an acceptable false-positive rate for a warning that's purely
informational and never blocks anything.

This is intentionally **not** an automatic "verify in sandbox before
applying" pipeline — see
[ADR-0001](0001-sandbox-subscription-scope.md#context) for why a clean
sandbox run doesn't actually prove a change is safe against dev/prod's real
accumulated state. The warning exists to prompt a human to *consider*
manually verifying via the sandbox `workflow_dispatch` job, not to gate
anything automatically.

## Consequences

- Adding a fourth environment means: a new root directory, a new App
  Registration + federated credential + RBAC role assignment, and two new
  workflow jobs (`plan-<env>`, `apply-<env>`) — no changes to `modules/`.
- The `Cost Management Contributor` grant on `sp-terraform-dev`/`-prod`,
  redundant since the RG-scoped-budget migration above, has been revoked
  at subscription scope (Azure RBAC roles, including this one, are
  assignable at management group, subscription, or resource group scope —
  each SP's existing RG-scoped Contributor role already covers everything
  this grant provided, so it wasn't re-added at RG scope either).
- `README.md`'s environment RBAC table reads "Contributor on its own RG"
  only for `dev`/`prod`, consistent with the revocation above.
