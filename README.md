# code-test — Terraform + Azure learning project

A real (not fictional) Azure-backed Terraform project used to learn dev/prod
environment isolation, CI/CD with GitHub Actions, and OIDC-based identity —
alongside a Databricks/Unity Catalog data platform, which is why some naming
decisions below exist specifically to avoid colliding with catalog-tier names
(`dev`/`test`/`prod`) that Unity Catalog also uses for a different concept
(data catalogs, not infrastructure).

For full diagrams (module composition, Azure resource topology, the git →
CI/CD → Azure flow, OIDC identity exchange) see
**[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**. For the reasoning behind
specific decisions, see the ADRs in `docs/adr/`.

## What this deploys

Two modules, reused across every environment:

- **`modules/analytics`** — a resource group + an ADLS Gen2 storage
  account (naming derived from `workload`/`environment`/`location`/`instance`)
- **`modules/budget_alert`** — a resource-group-scoped consumption budget
  with 20%/40% threshold notifications

```mermaid
flowchart TB
    subgraph modules["modules/ (shared, reusable, no state of its own)"]
        AG["analytics_group\nRG + ADLS Gen2 storage account"]
        BA["budget_alert\nconsumption budget, scoped to that RG"]
    end

    subgraph dev["environments/dev"]
        DM["main.tf"] --> AG
        DM --> BA
    end
    subgraph prod["environments/prod"]
        PM["main.tf"] --> AG
        PM --> BA
    end
    subgraph sandbox["sandbox/ (top-level, deliberately NOT under environments/)"]
        SM["main.tf"] --> AG
        SM --> BA
    end
```

## Environments

| Environment | Purpose | Lifecycle | CI identity | RBAC scope |
|---|---|---|---|---|
| `dev` | Real, Unity-Catalog-facing dev data platform | Long-lived | `sp-terraform-dev` | Contributor on its own resource group only |
| `prod` | Real, Unity-Catalog-facing prod data platform | Long-lived | `sp-terraform-prod` | Contributor on its own resource group only |
| `sandbox` | Disposable infra testing — never registered in Unity Catalog | Created/destroyed freely | `sp-terraform-sandbox` | Contributor on the **whole subscription** (see [ADR-0001](docs/adr/0001-sandbox-subscription-scope.md)) |

**What a clean sandbox run proves, and what it doesn't:** sandbox is
destroyed and rebuilt from empty on every run, so it can only validate
things that don't depend on history — that Azure's API accepts a given
configuration, that the CI identity's RBAC is sufficient, that a new
resource type wires up at all (all real failure modes `plan` can't catch,
since `plan` never calls Azure's actual validation). It cannot prove a
change is safe against `dev`/`prod`'s real accumulated state — existing
data, downstream consumers, or out-of-band drift. Don't read "sandbox
passed" as "safe to apply to dev/prod" — read it as "this can exist, and
this identity can create it."

Each environment is a separate Terraform root module — its own state key in
the shared remote backend (`sttfstateanalyticsneu01` / container `tfstate`),
its own `terraform.tfvars`. Terraform has no built-in "environment" concept;
this separation is purely directory + backend-key based. Shared, genuinely
environment-independent values (`subscription_id`, `notify_email`,
`workload`, `instance`) live in `environments/common.tfvars`, which — unlike
`terraform.tfvars` — is **not** auto-loaded and must always be passed
explicitly:

```bash
# from environments/dev or environments/prod:
terraform plan -var-file=../common.tfvars -var-file=terraform.tfvars

# from sandbox/ (one directory shallower, so one fewer ../):
terraform plan -var-file=../environments/common.tfvars -var-file=terraform.tfvars
```

`sandbox/` deliberately sits as a **top-level sibling** of `environments/`,
not nested inside it — the directory tree itself should say "this one isn't
a real data environment" without needing to read further. See
[ADR-0001](docs/adr/0001-sandbox-subscription-scope.md).

## CI/CD

- Every PR runs `fmt-check` → `plan-dev` (init, validate, plan, a
  destructive-change check, and the plan posted as a PR comment).
- Merging to `main` triggers `apply-dev` automatically — it applies the
  *exact* plan artifact `plan-dev` already produced, never a fresh plan —
  then `plan-prod` runs the same init/validate/plan/check sequence against
  `prod`.
- `apply-prod` sits behind the `production` GitHub Environment's
  required-reviewer gate; once approved, it applies the exact `plan-prod`
  artifact.
- `sandbox` never runs on push/PR — only on manual `workflow_dispatch`,
  from any branch, to verify a risky change against real Azure first.

Identity is OIDC-based throughout — Terraform's `azurerm` provider fetches
its own short-lived Azure AD token directly (via GitHub's auto-injected
OIDC token endpoint, exchanged through an Entra federated identity
credential per environment); no client secrets are stored anywhere. Each
environment has its own App Registration / Service Principal, so a
compromised or misconfigured `dev` pipeline cannot authenticate as `prod`.

See **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** for the full flow
diagram and **[ADR-0002](docs/adr/0002-pipeline-and-identity-architecture.md)**
for why each of these pieces is built the way it is.

## Repo layout

```text
code-test/
├── modules/
│   ├── analytics/                # RG + ADLS Gen2 storage account
│   └── budget_alert/             # RG-scoped consumption budget
├── environments/                 # real, long-lived, Unity-Catalog-facing
│   ├── common.tfvars             # shared, environment-independent values
│   ├── dev/                      # root module -- own state, own tfvars
│   └── prod/                     # root module -- own state, own tfvars
├── sandbox/                      # disposable infra testing -- NOT under environments/
├── docs/
│   ├── ARCHITECTURE.md           # diagrams: modules, Azure topology, CI/CD flow, OIDC
│   ├── azure-setup-commands.sh   # record of the one-time Azure bootstrap
│   └── adr/                      # architecture decision records
│       ├── 0001-sandbox-subscription-scope.md
│       └── 0002-pipeline-and-identity-architecture.md
├── .github/workflows/terraform.yml
└── deploy.sh                     # manual prod plan/apply helper
```

## Known limitations (by design, for now)

- Everything runs in **one Azure subscription** (Free Trial billing — Azure
  blocks creating additional subscriptions until upgraded to Pay-As-You-Go).
  See [ADR-0001](docs/adr/0001-sandbox-subscription-scope.md) for the
  concrete consequence of this.
- App registrations / service principals were created via one-time `az` CLI
  commands (recorded in `docs/azure-setup-commands.sh`), not via Terraform —
  this avoids a bootstrap circularity (the identity a pipeline authenticates
  as can't be created by that same pipeline's own run). A future step could
  move this into a separate, human-applied `bootstrap/` Terraform root using
  the `azuread` provider.
- The subscription-wide `Cost Management Contributor` grant on
  `sp-terraform-dev`/`sp-terraform-prod` predated the resource-group-scoped
  budget refactor (see
  [ADR-0002](docs/adr/0002-pipeline-and-identity-architecture.md#budget-scope))
  and has since been revoked — each SP's existing RG-scoped Contributor
  role already covers everything it was granted for.
