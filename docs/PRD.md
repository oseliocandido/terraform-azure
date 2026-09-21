# Product Requirements Document

## Retail Sales Analytics Platform

**Version:** 1.1 · **Status:** In progress (Development delivered, Production pending) ·
**Owner:** Data Engineering · **Primary consumer:** Sales

This document states what the business needs. It contains no technology or
implementation detail; those are in [ARCHITECTURE.md](../ARCHITECTURE.md) and
[IMPLEMENTATION.md](IMPLEMENTATION.md).

---

# 1. Executive Summary

The company sells through physical stores and an online store. Sales data sits
in two operational systems (point of sale and e-commerce) with no central place
to store or analyze it over time.

This project delivers the **cloud platform foundation** for sales analytics: a
central, secure, reproducible place to keep sales data and analyze it
historically. It delivers the platform, not the data pipelines that will fill it.

# 2. Business Problem

- **Inconsistent numbers.** Revenue is calculated differently depending on which
  system is used.
- **No history.** Both systems show current state only; there is no durable
  record independent of their own retention.
- **Fragmented data.** Reporting combines exports from two systems by hand.
- **Does not scale.** Manual extraction and spreadsheets break as volume grows.
- **Hard to reproduce.** Environments should not depend on manual cloud setup.

# 3. Goals

Provide a platform that supports:

- centralized storage of sales data;
- historical, revenue and sales-performance analysis, by store and by channel
  (in-store vs. online);
- separate Development and Production environments;
- five years of retained history (§9), the one volume figure treated as firm.

Store count and transaction volume are deliberately **not** stated as targets:
no sizing study exists, and an unvalidated number would silently drive design
choices. Capacity is validated once compute is sized.

# 4. Project Scope

In scope: cloud analytical storage, Databricks as the analytics platform,
Development and Production environments, identity and access management,
secret handling, reproducible infrastructure, controlled change through version
control, environment isolation, and cost/ownership metadata.

# 5. Non-Goals

Not in this project: replacing the POS or e-commerce systems, customer-facing
applications, machine learning, real-time fraud detection, production ingestion
or transformation pipelines, dashboards, becoming the master system for product,
customer or store data, advanced networking, and prescribing how change history
within a dataset is modeled.

# 6. Users and Stakeholders

| Group | Needs | Access |
|---|---|---|
| **Report consumers** (Sales) | Curated, business-ready revenue and performance figures | Read-only, business-ready data only |
| **Analysts** (Sales) | The above, plus drilling a number back toward its inputs | Read-only, refined and business-ready data |
| **Data Engineering** | Build and run analytical workloads and future pipelines; isolated, reproducible environments | Read and write on their domain's data |

# 7. Business Data Requirements

The initial domain is **Sales** (POS and e-commerce transactions). A second
domain, **Marketing**, shares the platform with the same access model, so several
business domains can use it without seeing each other's data.

Data is modeled around business questions, not either source system's schema.
Raw data from each source system is kept **once**, in one place; each domain
builds its own refined and business-ready datasets from it rather than keeping a
private copy of the raw data.

# 8. Analytical Data Organization

Data moves through three stages, known as medallion architecture:
**bronze** (raw), **silver** (refined), **gold** (business-ready). The role
split in §6 follows it: report consumers see gold only, analysts see silver and
gold, engineers see all stages.

# 9. Historical Data Retention

Sales data is retained for **five years from ingestion**, then may be deleted.
Older data may sit in a cheaper, slower tier if it is not deleted early. History
stays available independently of the POS and e-commerce systems' own lifecycle.

# 10. Environment Requirements

Two permanent environments, **Development** and **Production**, managed
independently: a change or failure in Development must not affect Production.

# 11. Security Requirements

- Users sign in with the organization's identity platform.
- Workloads use dedicated identities; there are no long-lived credentials in
  source code.
- Access is least-privilege, and Production is more restricted than Development.
  Production data is intended to be written by automated identities rather than
  people.
- Secrets that cannot be avoided are stored securely.
- Development must never gain unrestricted access to Production.

# 12. Cost and Resource Management

Every resource carries tags for **environment, workload, owner, cost center and
managed-by**, so Development and Production costs can be told apart, and each
environment has a budget with spend alerts.

# 13. Reliability Requirements

- Infrastructure can be recreated entirely from source-controlled definitions.
  A few one-time account-level steps that automation cannot create for itself are
  acceptable if documented and repeatable.
- Environments do not depend on each other.
- **Production data is protected against accidental loss:** deleted data stays
  recoverable for at least 14 days in Production (a shorter period is fine in
  Development), and an ordinary change cannot destroy Production storage;
  destroying it takes a deliberate, reviewed change.

# 14. Technology Constraints

Microsoft Azure, Azure Databricks as the compute platform, and Terraform for
infrastructure.

# 15. Requirements Boundary

This document says **what** the business requires. How it is built is decided in
[ARCHITECTURE.md](../ARCHITECTURE.md) and [IMPLEMENTATION.md](IMPLEMENTATION.md).

# 16. Future Scope

Later phases, outside this project: detailed networking (private connectivity,
network controls), data pipelines and orchestration, further domains
(inventory, product, customer, supplier), and data quality, monitoring,
streaming and machine learning.

# 17. Acceptance Criteria

**Infrastructure**
- Development and Production can each be provisioned from version-controlled
  definitions, are independently managed, and are stored centrally.
- Changes can be reviewed before deployment, and Production changes need approval.

**Security**
- Organizational identities are used; no unnecessary long-lived credentials or
  hard-coded secrets; Production access is restricted; environment boundaries
  are enforced.

**Platform foundation**
- Durable analytical storage for sales data; Azure Databricks available as the
  compute platform.
- Five-year retention is enforced at the infrastructure level.
- Production storage is protected against accidental deletion (§13).
- Capacity for expected data volumes is validated once compute is sized.

**Engineering**
- Reusable components are separate from environment-specific configuration.
- Changes are validated automatically.
- Differences between the source-controlled definitions and what is deployed can
  be detected on demand, without changing anything.
- Resources are identifiable by environment, workload, owner and cost.

# 18. Success Metrics

| Metric | Target |
|---|---:|
| Development and Production infrastructure managed through Terraform | 100% |
| Production changes made outside Terraform | 0 |
| Production static CI/CD credentials | 0 |
| Production secrets committed to source control | 0 |
| Infrastructure changes traceable through version control | 100% |
| Required infrastructure reproducible from code | 100% |
| Environments with an on-demand drift check | 100% |

Data-pipeline metrics (success rate, quality, freshness) are out of scope.

# 19. Final Business Outcome

A reproducible, secure, environment-separated cloud foundation on which sales
data engineering can later be built, giving the business one historical,
reportable view of sales.
