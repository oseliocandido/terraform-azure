# Product Requirements Document

## Retail Sales Analytics Platform

**Document version:** 3.0
**Status:** Proposed
**Owner:** Data Engineering
**Primary consumer:** Sales

> This is the business-requirements document for a future, larger
> initiative — it does not describe infrastructure already built in this
> repo. For the architecture decisions this PRD requires, see
> [ARCHITECTURE.md](ARCHITECTURE.md); for the concrete Terraform/CI-CD
> implementation spec, see [IMPLEMENTATION.md](IMPLEMENTATION.md). This
> document intentionally contains **no** Terraform, Azure resource, or
> CI/CD implementation detail, and **no** data-pipeline/transformation
> logic (e.g. how change over time is captured in a dataset) — only what
> the business needs the infrastructure to be capable of.
>
> **Scope note (v3.0):** narrowed from a multi-department, multi-domain
> platform to a single use case — Sales — since a resource group already
> represents one business case per environment (see
> [ARCHITECTURE.md](ARCHITECTURE.md)); there's no need to model multiple
> departments to demonstrate that. Inventory, customer, supplier, and
> product domains, and anything describing *how* historical change is
> modeled inside a dataset, were removed as out of scope for an
> infrastructure-focused project — that's data-pipeline design, not
> infrastructure.

---

# 1. Executive Summary

The company operates a network of physical retail stores and an online store.

Sales transaction data currently exists across two operational systems —
the point-of-sale system and the e-commerce platform — with no centralized
place to store or analyze it historically.

The company requires a centralized analytical platform that provides a
consistent foundation for sales reporting and historical analysis.

The initial project will establish the **cloud infrastructure required to
support this analytical platform**, using Infrastructure as Code.

The project is intentionally focused on the **underlying platform and
infrastructure rather than implementing production data pipelines**.

The resulting platform should provide the infrastructure foundation
required for:

* Centralized analytical data storage for sales data.
* Historical analytical data retention.
* Separate Development and Production environments.
* Secure access to analytical resources.
* Reproducible infrastructure.
* Controlled infrastructure changes.
* Future implementation of sales data ingestion and transformation workloads.

---

# 2. Business Problem

Sales data originates from two systems:

* The point-of-sale system (physical stores).
* The e-commerce platform (online store).

Each system has a different schema and update frequency.

This makes it difficult to establish a consistent historical view of sales
performance, because:

### 2.1 Inconsistent business information

Revenue and sales metrics may be calculated differently depending on which
system's data is used.

### 2.2 Limited historical analysis

Both operational systems represent current transaction state; there is no
durable, queryable historical record independent of the operational
systems' own retention.

### 2.3 Fragmented analytical data

Sales reporting depends on combining exports from two separate systems
instead of a centralized analytical foundation.

### 2.4 Limited scalability

Manual extraction and spreadsheet-based analysis do not scale as
transaction volume grows.

### 2.5 Difficult environment management

The analytical platform requires reproducible Development and Production
environments. Infrastructure should not depend on manual configuration
performed directly in the cloud environment.

---

# 3. Goals

The project goal is to establish a cloud-based analytical platform
foundation capable of supporting:

* Centralized sales data storage.
* Historical sales analysis.
* Revenue and sales-performance analysis.
* Store-level and channel-level (in-store vs. e-commerce) analysis.
* Future sales data ingestion and transformation workloads.
* Five years of historical analytical data — see
  [§9](#9-historical-data-retention), the one volume-related figure this
  PRD treats as a firm business requirement.

**Store count and daily transaction volume are deliberately not stated
as targets here.** No capacity/throughput sizing study has been done yet,
and this project does not include cluster or compute sizing work (see
[BACKLOG.md](BACKLOG.md#compute--cluster-architecture--not-yet-specified)).
Publishing an unvalidated number invites design decisions (storage
tiering, cluster sizing, partitioning) to silently anchor on a figure
nobody actually confirmed. The infrastructure is designed to scale
horizontally regardless of the eventual number — Databricks/Unity
Catalog and ADLS Gen2 don't require a pre-committed volume figure to be
provisioned — and a real sizing study, once done, gets folded in here as
a revision, not treated as a blocker to this phase.

---

# 4. Project Scope

The project is primarily an **Infrastructure as Code implementation
exercise for a cloud data platform**.

The project will establish the infrastructure foundation required by the
future sales analytics platform.

The implementation scope includes:

* Cloud analytical storage.
* Databricks analytical infrastructure.
* Development and Production environments.
* Identity and access management required by the platform.
* Secure secret management where required.
* Infrastructure deployment through Infrastructure as Code.
* Reproducible infrastructure configuration.
* Infrastructure change management through version control and CI/CD.
* Environment isolation.
* Cost and resource ownership metadata.

The project does **not** require implementation of the actual production
data pipelines.

Sales data ingestion and transformation requirements described in this
document represent the **business capability the infrastructure must be
capable of supporting**, not a pipeline that must be implemented as part
of this project.

---

# 5. Non-Goals

The first version will not:

* Replace the operational POS system.
* Replace the e-commerce platform.
* Build customer-facing applications.
* Implement machine-learning models.
* Implement real-time fraud detection.
* Implement production data ingestion pipelines.
* Implement production data transformation pipelines.
* Build dashboards or BI applications.
* Become the master system for product, customer, or store information.
* Implement advanced networking architecture.
* Prescribe how historical change within a dataset is modeled — that is a
  data-pipeline design decision, made when a pipeline is actually built,
  not an infrastructure requirement.

Networking will remain a **future architecture/backlog item** unless it
becomes necessary to provision the initial platform.

---

# 6. Users and Stakeholders

## Sales

Requires the analytical platform to support:

* Revenue analysis.
* Sales-performance analysis.
* Historical revenue trends.
* Revenue by store.
* Revenue by channel (in-store vs. e-commerce).

## Data Engineering

Requires a platform that can:

* Support analytical workloads for sales data.
* Support historical data retention.
* Support future data pipelines.
* Provide isolated environments.
* Be reproduced through Infrastructure as Code.
* Be securely accessed by users and workloads.

---

# 7. Business Data Requirements

The analytical platform's initial scope is the **Sales** domain: sales
transactions from the point-of-sale system and the e-commerce platform.

The platform should allow sales data to be represented independently from
the structure of either source system — analytical datasets should be
designed around **business questions about sales**, not simply reproducing
either source system's schema.

---

# 8. Analytical Data Organization

The platform should support a logical separation between different stages
of sales data as it moves from raw source extracts toward business-ready,
reportable datasets.

The exact storage/organizational implementation of these stages is an
architecture decision — see
[ARCHITECTURE.md](ARCHITECTURE.md#analytical-data-layering).

The infrastructure must provide the storage and analytical capabilities
required to implement this layering when pipelines are built in the future.

---

# 9. Historical Data Retention

The analytical platform should support long-term historical analysis.

**The business requirement is to retain sales analytical data for five
years from the date it was ingested.** Data older than five years may be
deleted; data does not need to remain queryable at full cost/performance
for the entire five years (a lower-cost storage tier is acceptable for
older data, provided it is not deleted before the five-year mark).

Historical data should remain available independently from the lifecycle
of the point-of-sale and e-commerce source systems.

The infrastructure should therefore support scalable, durable, and
cost-tiered analytical storage with an enforced retention period — see
[ARCHITECTURE.md](ARCHITECTURE.md#data-retention-and-lifecycle-policy) for
how this is technically enforced.

---

# 10. Environment Requirements

The platform will initially have two permanent environments:

```text
DEV
PROD
```

Development and Production must be independently managed.

A change or failure in Development must not unintentionally affect
Production.

A temporary sandbox environment may be used for infrastructure
experimentation and validation. The sandbox is not a permanent business
environment.

---

# 11. Security Requirements

The platform must provide controlled access to analytical resources.

Requirements include:

* Users should authenticate using the organization's identity platform
  where supported.
* Workloads should use dedicated identities.
* Access should follow least-privilege principles.
* Production access should be more restricted than Development access.
* Credentials should not be embedded in source code.
* Secrets that cannot be eliminated through identity-based authentication
  should be securely managed.
* Development workloads must not accidentally gain unrestricted access to
  Production resources.

The detailed Azure/Databricks security architecture is defined separately
— see [ARCHITECTURE.md](ARCHITECTURE.md).

---

# 12. Cost and Resource Management

The platform should provide sufficient resource metadata to allow
infrastructure costs and ownership to be identified.

Resources should consistently identify concepts such as:

```text
environment
workload
owner
cost center
managed by
```

The platform should make it possible to distinguish Development and
Production infrastructure costs.

---

# 13. Reliability Requirements

The infrastructure must support the future sales analytics platform
without creating unnecessary coupling between environments.

The platform should provide durable analytical storage and infrastructure
that can be recreated from source-controlled definitions.

The underlying infrastructure should not depend on manually configured
resources that cannot be reproduced.

---

# 14. Technology Constraints

The initial platform will be implemented on **Microsoft Azure**.

The analytical compute platform will use **Azure Databricks**.

Infrastructure will be managed using **Terraform**.

The exact provider configuration and resource implementation are
determined during architecture and implementation design — see
[ARCHITECTURE.md](ARCHITECTURE.md) and [IMPLEMENTATION.md](IMPLEMENTATION.md).

---

# 15. Architecture Decision Boundary

This PRD defines **what the business and platform require**. It
intentionally does not prescribe the complete technical architecture —
that is the job of [ARCHITECTURE.md](ARCHITECTURE.md) and, at the
implementation level, [IMPLEMENTATION.md](IMPLEMENTATION.md).

```text
                 PRD (this document)
                        │
                        ▼
              Business Requirements
                        │
                        ▼
             ARCHITECTURE.md
        (Azure / Databricks / Terraform
              decisions, in response
               to this PRD's needs)
                        │
                        ▼
             IMPLEMENTATION.md
       (exact module layout, providers,
          CI/CD stages, naming, state)
```

---

# 16. Backlog / Future Scope

The following items are intentionally outside the initial implementation
scope:

### Networking

Detailed network architecture should be addressed in a future architecture
phase. Potential future requirements include private endpoints, private
connectivity, Databricks network architecture, network security controls,
and controlled outbound connectivity.

### Data Pipelines

Actual sales data ingestion, transformation, and orchestration — including
how historical change within a dataset is modeled — are future
implementation work, not part of this infrastructure project.

### Additional Business Domains

Inventory, product, customer, and supplier data are explicitly out of
scope for this phase. If a future phase extends the platform to these
domains, that extension gets its own PRD/architecture review rather than
being retrofitted into this one.

### Data Quality, Monitoring, Streaming, Machine Learning

All future capabilities, not required by this infrastructure phase.

---

# 17. Acceptance Criteria

The project will be considered successful when:

## Infrastructure

* Development infrastructure can be provisioned using Terraform.
* Production infrastructure can be provisioned using Terraform.
* Infrastructure can be reproduced from version-controlled definitions.
* Development and Production infrastructure are independently managed.
* Infrastructure configuration is durably stored centrally, not dependent
  on any single engineer's machine.
* Infrastructure changes can be reviewed before deployment.

## Security

* Azure resources can use organizational identities where supported.
* Workloads do not depend on unnecessary long-lived credentials.
* Production access is appropriately restricted.
* Secrets are not hardcoded in Terraform source code.
* Environment boundaries are enforced.

## Analytical Platform Foundation

* The infrastructure provides durable analytical storage for sales data.
* Azure Databricks can be provisioned and used as the analytical compute
  platform.
* The platform enforces the five-year retention requirement at the
  infrastructure level.
* The infrastructure can support the expected initial data volumes.

## Engineering

* Terraform configuration is version controlled.
* Reusable infrastructure components are separated from
  environment-specific configuration.
* Infrastructure changes are validated through automation.
* Production deployment requires appropriate approval.
* Resources can be identified by environment, workload, ownership, and
  cost-related metadata.

---

# 18. Success Metrics

| Metric                                                        | Target |
| ------------------------------------------------------------- | -----: |
| Production infrastructure managed through Terraform           |   100% |
| Development infrastructure managed through Terraform          |   100% |
| Production infrastructure changes performed outside Terraform |      0 |
| Production static CI/CD credentials                           |      0 |
| Production secrets committed to source control                |      0 |
| Independent DEV and PROD infrastructure lifecycle              |   100% |
| Infrastructure changes traceable through version control      |   100% |
| Required analytical infrastructure reproducible from code     |   100% |

Data-pipeline metrics (pipeline success rate, data-quality coverage, data
freshness) are outside the scope of this infrastructure project.

---

# 19. Final Business Outcome

The project will establish a reproducible cloud foundation for a future
sales analytics platform.

```text
                      SALES
                        │
                        ▼
              Analytical Platform
                        │
              ┌─────────┴─────────┐
              ▼                   ▼
          Historical          Reportable
            Data           Sales Datasets
```

The immediate objective is **not to build the data pipelines**.

The immediate objective is to demonstrate the ability to design and
provision the **underlying cloud infrastructure required by a
production-oriented analytical data platform**, using Terraform in a
secure, reproducible, environment-separated manner. See
[ARCHITECTURE.md](ARCHITECTURE.md) for how that infrastructure is
reproducible and environment-isolated in practice.

The resulting infrastructure provides the foundation upon which future
sales data engineering workloads can be implemented.
