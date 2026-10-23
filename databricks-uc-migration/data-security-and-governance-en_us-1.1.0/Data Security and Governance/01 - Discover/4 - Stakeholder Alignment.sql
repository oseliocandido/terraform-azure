-- Databricks notebook source
-- MAGIC %md-sandbox
-- MAGIC <div style="display:flex; align-items:center; padding:10px 18px; background:#F8F9FA; border-bottom:1px solid #E0E0E0; gap:10px;">
-- MAGIC   <img src="https://cdn.simpleicons.org/databricks/FF3621" width="22" height="22"/>
-- MAGIC   <div style="font-size:14px; color:#666; white-space:nowrap;">
-- MAGIC     <span style="font-weight:600; color:#333;">Academy</span>
-- MAGIC     <span style="margin:0 10px; color:#bbb;">|</span>
-- MAGIC     <span>Data Security & Governance Delivery Expert</span>
-- MAGIC     <span style="margin:0 10px; color:#bbb;">|</span>
-- MAGIC     <span>Discover</span>
-- MAGIC     <span style="margin:0 10px; color:#bbb;">|</span>
-- MAGIC     <span style="font-weight:600; color:#eb1900;">Stakeholder Alignment</span>
-- MAGIC   </div>
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md
-- MAGIC
-- MAGIC <div style="text-align: center; line-height: 0; padding-top: 9px;">
-- MAGIC   <img
-- MAGIC     src="https://databricks.com/wp-content/uploads/2018/03/db-academy-rgb-1200px.png"
-- MAGIC     alt="Databricks Learning"
-- MAGIC   >
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC # Stakeholder Alignment
-- MAGIC
-- MAGIC Before beginning any UC migration project, let's cover some of the requirements that need to be satisfied before we begin.
-- MAGIC
-- MAGIC <div style="border-left: 4px solid #ff9800; background: #fff3e0; padding: 16px 20px; border-radius: 8px; margin: 16px 0;">
-- MAGIC   <div style="display: flex; align-items: center; gap: 12px;">
-- MAGIC     <span style="font-size: 24px;">⚠️</span>
-- MAGIC     <div>
-- MAGIC       This notebook is not supported for execution on Databricks Academy provided workspaces. The material is intended to be a study guide, to be run in your own sandbox environments if you would like. Databricks Academy does not provide an account with a live HMS, administrator level access, or an AWS account, all of which would be required to perform all the activities in these notebooks.<p>
-- MAGIC       <strong>The notebooks flagged as labs in the agenda can be run in a Databricks Academy provided Vocareum workspace and allow you to put the concepts into practice.</strong>
-- MAGIC     </div>
-- MAGIC   </div>
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Learning Objectives
-- MAGIC
-- MAGIC By the end of this lesson, you will be able to:
-- MAGIC
-- MAGIC - Align customer, partner, and PS RSA roles
-- MAGIC - Tag use cases for UC $DBU uplift
-- MAGIC - Finalize sign-off on readiness report

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## A. Role Alignment
-- MAGIC
-- MAGIC - **Customer platform/ops:** 
-- MAGIC    - Account/Metastore setup
-- MAGIC    - Workspace assignment
-- MAGIC    - Credentials/external locations
-- MAGIC    - CI/CD
-- MAGIC    - Production readiness sign-offs
-- MAGIC - **Customer data producers:**
-- MAGIC    - Table/view migration approach
-- MAGIC    - Pipeline refactors (3-level namespace)
-- MAGIC    - Deprecation PSAs
-- MAGIC    - Consumer communication timelines
-- MAGIC - **Security/governance:**
-- MAGIC    - Group/role model
-- MAGIC    - ABAC/RBAC patterns
-- MAGIC    - Catalog/schema ownership
-- MAGIC    - Audit/lineage visibility
-- MAGIC    - Exception handling policies
-- MAGIC - **Partner team:**
-- MAGIC    - Implementation execution
-- MAGIC    - Refactoring support
-- MAGIC    - Test/validation scripts
-- MAGIC    - BI connector updates
-- MAGIC    - Knowledge transfer as per SOW
-- MAGIC - **PS RSA (advisory SME):**
-- MAGIC    - Orchestrates readiness
-- MAGIC    - Migration options (in-place vs. parallel)
-- MAGIC    - Blockers escalation
-- MAGIC    - Go-Live checklist
-- MAGIC    - Project close checklist
-- MAGIC    - Handover package

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## B. Tag Use Cases for UC $DBU Uplift
-- MAGIC
-- MAGIC 1. Identify migratable workloads using UCX assessment and system telemetry (legacy HMS tables, DBFS file workloads, mounts, model serving, etc.).
-- MAGIC 1. Estimate UC $DBU uplift by mapping workloads to UC-supported features (UC-enabled compute, volumes for file IO, external locations, table ACLs, lineage, etc.) and tracking “eligible/migratable DBUs.”
-- MAGIC 1. Prioritize high-ROI candidates (top workloads by eligible DBUs, business-critical dashboards, heavily shared data products).
-- MAGIC 1. Record tagging decisions and expected uplift in the UC Upgrade Plan for downstream planning and measurement.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ##C.Finalize Sign-off
-- MAGIC
-- MAGIC The readiness report should include the following:
-- MAGIC - **UCX assessment summary:** identities, credentials/locations, table/view eligibility, jobs, clusters, mounts, BI connectors.
-- MAGIC - **Upgrade Plan baseline:** sequencing, effort estimates, risks, dependencies, rollback options; cloud/provider-specific tabs as applicable.
-- MAGIC - **Draft governance model:** catalogs/schemas ownership, group alignment, exception handling, audit/lineage targets.
-- MAGIC
-- MAGIC Sign-off criteria:
-- MAGIC - Alignment on roles and RACI for all major activities.
-- MAGIC - Prioritized list of UC uplift use cases and tagging approach agreed.
-- MAGIC - No open Sev-1 readiness gaps; mitigation plans documented for Sev-2/3 items with owners and timelines.
-- MAGIC
-- MAGIC Outcome: Stakeholders approve the readiness report and authorize the move into UC design and migration execution.

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC &copy; <span id="dbx-year"></span> Databricks, Inc. All rights reserved. Apache, Apache Spark, Spark, the Spark Logo, Apache Iceberg, Iceberg, and the Apache Iceberg logo are trademarks of the <a href="https://www.apache.org/" target="_blank">Apache Software Foundation</a>.<br/><br/><a href="https://databricks.com/privacy-policy" target="_blank">Privacy Policy</a> | <a href="https://databricks.com/terms-of-use" target="_blank">Terms of Use</a> | <a href="https://help.databricks.com/" target="_blank">Support</a>
-- MAGIC <script>
-- MAGIC   document.getElementById("dbx-year").textContent = new Date().getFullYear();
-- MAGIC </script>