# Databricks notebook source
# MAGIC %md-sandbox
# MAGIC <div style="display:flex; align-items:center; padding:10px 18px; background:#F8F9FA; border-bottom:1px solid #E0E0E0; gap:10px;">
# MAGIC   <img src="https://cdn.simpleicons.org/databricks/FF3621" width="22" height="22"/>
# MAGIC   <div style="font-size:14px; color:#666; white-space:nowrap;">
# MAGIC     <span style="font-weight:600; color:#333;">Academy</span>
# MAGIC     <span style="margin:0 10px; color:#bbb;">|</span>
# MAGIC     <span>Data Security & Governance Delivery Expert</span>
# MAGIC     <span style="margin:0 10px; color:#bbb;">|</span>
# MAGIC     <span>Cutover</span>
# MAGIC     <span style="margin:0 10px; color:#bbb;">|</span>
# MAGIC     <span style="font-weight:600; color:#eb1900;">Acceptance and Sign-off</span>
# MAGIC   </div>
# MAGIC </div>

# COMMAND ----------

# MAGIC %md
# MAGIC <div style="text-align: center; line-height: 0; padding-top: 9px;">
# MAGIC <img src="https://databricks.com/wp-content/uploads/2018/03/db-academy-rgb-1200px.png" alt="Databricks Learning">
# MAGIC </div>

# COMMAND ----------

# MAGIC %md-sandbox
# MAGIC # Acceptance and Sign-off
# MAGIC
# MAGIC With cutover complete, this lesson standardizes how to secure customer acceptance, validate stable UC operations, and close out the migration with documented lessons learned.
# MAGIC
# MAGIC <div style="border-left: 4px solid #ff9800; background: #fff3e0; padding: 16px 20px; border-radius: 8px; margin: 16px 0;">
# MAGIC   <div style="display: flex; align-items: center; gap: 12px;">
# MAGIC     <span style="font-size: 24px;">⚠️</span>
# MAGIC     <div>
# MAGIC       This notebook is not supported for execution on Databricks Academy provided workspaces. The material is intended to be a study guide, to be run in your own sandbox environments if you would like. Databricks Academy does not provide an account with a live HMS, administrator level access, or an AWS account, all of which would be required to perform all the activities in these notebooks.<p>
# MAGIC       <strong>The notebooks flagged as labs in the agenda can be run in a Databricks Academy provided Vocareum workspace and allow you to put the concepts into practice.</strong>
# MAGIC     </div>
# MAGIC   </div>
# MAGIC </div>

# COMMAND ----------

# MAGIC %md
# MAGIC ## Learning Objectives
# MAGIC
# MAGIC By the end of this lesson, you will be able to:
# MAGIC
# MAGIC - Secure customer acceptance
# MAGIC - Confirm stable UC operations
# MAGIC - Finalize lessons-learned log

# COMMAND ----------

# MAGIC %md
# MAGIC ## A. Customer Acceptance
# MAGIC
# MAGIC At this stage, present and file evidence as outlined in this section.

# COMMAND ----------

# MAGIC %md
# MAGIC ### A1. Evidence
# MAGIC
# MAGIC - **Re-execution evidence:** representative jobs, dashboards, connectors completed under UC; baseline vs. post-UC performance notes.
# MAGIC - **Access validation:** confirmations that intended users/groups have correct UC privileges; any exceptions documented.
# MAGIC - **Data parity checks:** schema/row-level sanity checks (e.g., producer-run comparisons for high-risk tables).

# COMMAND ----------

# MAGIC %md-sandbox
# MAGIC ### A2. Acceptance Criteria
# MAGIC
# MAGIC The following provide examples constituting an acceptance criteria checklist:
# MAGIC
# MAGIC - All critical workloads operate on UC with successful recent runs (time-boxed window agreed with customer).
# MAGIC - No Sev-1/Sev-2 incidents open related to UC migration; Sev-3 mitigations documented and owners assigned.
# MAGIC - Access and governance: catalog/schema/table permissions validated; audit events visible; lineage present for key pipelines.
# MAGIC - Business dashboards render correctly (run-as-owner where appropriate); consumers notified of deprecation timelines.
# MAGIC
# MAGIC <div style="border-left: 4px solid #1976d2; background: #e3f2fd; padding: 16px 20px; border-radius: 8px; margin: 16px 0;">
# MAGIC <div style="display: flex; align-items: center; gap: 12px;">
# MAGIC   <span style="font-size: 24px;">ℹ️</span>
# MAGIC   <div>
# MAGIC     Provide acceptance via the <i>Delivery Phase - Sign Off</i> template in the Service Delivery Kit and attach the evidence pack.
# MAGIC   </div>
# MAGIC </div>

# COMMAND ----------

# MAGIC %md
# MAGIC ## B. Stable Operation

# COMMAND ----------

# MAGIC %md
# MAGIC ### B1. Stabilization Checks
# MAGIC
# MAGIC - **Incidents and alerts:** monitor for migration-related errors; verify alerting works on UC compute/jobs.
# MAGIC - **Lineage and observability:** confirm lineage sync for migrated pipelines; ensure audit events and system telemetry are populated.
# MAGIC - **Permissions and access patterns:** spot-check role/group grants; validate external locations/volumes use is correct for retired DBFS mounts (if applicable).
# MAGIC - **Adoption/coverage tracking:** use UC Migration Tracker to quantify UC-eligible DBUs migrated and identify missed opportunities (where available).

# COMMAND ----------

# MAGIC %md
# MAGIC ### B2. Recommended Artifacts
# MAGIC
# MAGIC - UC Go-Live Checklist with validation steps and rollback/backout references.
# MAGIC - Short stabilization summary: incidents observed, mitigations applied, post-cutover SLO/SLA notes.

# COMMAND ----------

# MAGIC %md
# MAGIC ## C. Finalize Lessons Learned
# MAGIC
# MAGIC Capture concrete improvements for future waves:
# MAGIC - **What worked well:** approach/sequence, tooling (UCX, wizard), communications cadence.
# MAGIC - **Issues/gaps:** product limitations, environment constraints, dependency surprises, CI/CD friction.
# MAGIC - **Refactors needed:** code patterns (namespace, mounts), BI connection strings, policy updates.
# MAGIC - **Process improvements:** evidence collection automation, clearer acceptance criteria, earlier consumer profiling.
# MAGIC
# MAGIC Store the log alongside the project closeout package:
# MAGIC - Technical Design Document, UC Upgrade Plan, runbook/troubleshooting guide, remaining-workspace migration guide and ownership model.

# COMMAND ----------

# MAGIC %md
# MAGIC ## D. Formal Sign-off
# MAGIC
# MAGIC - Review acceptance criteria and stabilization checks in the meeting.
# MAGIC - Obtain customer sign-off (template) and archive evidence pack.
# MAGIC - Handover: share TDD, runbook, upgrade plan, and contact points for ongoing production support/governance.
# MAGIC - Schedule post-cutover governance review and dashboard lineage audit (monthly or agreed cadence).

# COMMAND ----------

# MAGIC %md-sandbox
# MAGIC &copy; <span id="dbx-year"></span> Databricks, Inc. All rights reserved. Apache, Apache Spark, Spark, the Spark Logo, Apache Iceberg, Iceberg, and the Apache Iceberg logo are trademarks of the <a href="https://www.apache.org/" target="_blank">Apache Software Foundation</a>.<br/><br/><a href="https://databricks.com/privacy-policy" target="_blank">Privacy Policy</a> | <a href="https://databricks.com/terms-of-use" target="_blank">Terms of Use</a> | <a href="https://help.databricks.com/" target="_blank">Support</a>
# MAGIC <script>
# MAGIC   document.getElementById("dbx-year").textContent = new Date().getFullYear();
# MAGIC </script>