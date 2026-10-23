# Databricks notebook source
# MAGIC %md-sandbox
# MAGIC <div style="display:flex; align-items:center; padding:10px 18px; background:#F8F9FA; border-bottom:1px solid #E0E0E0; gap:10px;">
# MAGIC   <img src="https://cdn.simpleicons.org/databricks/FF3621" width="22" height="22"/>
# MAGIC   <div style="font-size:14px; color:#666; white-space:nowrap;">
# MAGIC     <span style="font-weight:600; color:#333;">Academy</span>
# MAGIC     <span style="margin:0 10px; color:#bbb;">|</span>
# MAGIC     <span style="font-weight:600; color:#eb1900;">Data Security & Governance Delivery Expert</span>
# MAGIC   </div>
# MAGIC </div>

# COMMAND ----------

# MAGIC %md
# MAGIC
# MAGIC <div style="text-align: center; line-height: 0; padding-top: 9px;">
# MAGIC   <img
# MAGIC     src="https://databricks.com/wp-content/uploads/2018/03/db-academy-rgb-1200px.png"
# MAGIC     alt="Databricks Learning"
# MAGIC   >
# MAGIC </div>

# COMMAND ----------

# MAGIC %md
# MAGIC
# MAGIC # Course Overview
# MAGIC
# MAGIC This course provides a comprehensive guide to migrating from Hive metastore to Unity Catalog, focusing on leveraging Unity Catalog for secure, governed, and scalable data operations. Participants will gain practical knowledge of Databricks architecture, data governance, and migration strategies, while learning to assess readiness, inventory data assets, refactor workloads, and ensure smooth, traceable transitions. The course emphasizes hands-on application of Databricks capabilities and integration with third-party tools to optimize code, data, and access migrations.

# COMMAND ----------

# MAGIC %md
# MAGIC ## Learning Objectives
# MAGIC
# MAGIC By the end of this course, you will be able to:
# MAGIC
# MAGIC - Recognize the benefits and value of migrating from Hive Metastore (HMS) to Unity Catalog (UC).
# MAGIC - Prepare effectively for a migration project, including assessing readiness and inventorying assets.
# MAGIC - Apply Databricks capabilities and third-party tools to perform code, data, and access migrations.
# MAGIC - Design and implement secure, governed, and scalable data operations using Unity Catalog.
# MAGIC

# COMMAND ----------

# MAGIC %md
# MAGIC ## Prerequisites
# MAGIC
# MAGIC Your successful participation in this course will benefit greatly from a foundation in the following, beginning with Databricks Platform Proficiencies, including a grasp of:
# MAGIC
# MAGIC - Configuration and optimization of compute resources, including SQL Warehouses, Jobs, and Workflows.
# MAGIC - Experience with Lakehouse workflows, serverless compute, and Lakeflow bundles.
# MAGIC
# MAGIC
# MAGIC In terms of real-world experience, we recommend:
# MAGIC - At least 6 months of building Spark SQL or PySpark ETL pipelines in production or sandbox environments.
# MAGIC - Familiarity with managing data, permissions, and workloads in cloud environments (AWS, Azure, or GCP).

# COMMAND ----------

# MAGIC %md
# MAGIC ## Module Structure
# MAGIC
# MAGIC | Module | Time |
# MAGIC |:----:|-------|
# MAGIC | [Discover]($./01 - Discover/AGENDA) | 60 min|
# MAGIC | [Design]($./02 - Design/AGENDA) | 80 min|
# MAGIC | [Setup]($./03 - Setup/AGENDA) | 90 min|
# MAGIC | [Execute]($./04 - Execute/AGENDA) | 80 min|
# MAGIC | [Cutover]($./05 - Cutover/AGENDA) | 30 min|
# MAGIC | [Closeout]($./06 - Closeout/AGENDA) | 20 min|

# COMMAND ----------

# MAGIC %md-sandbox
# MAGIC &copy; <span id="dbx-year"></span> Databricks, Inc. All rights reserved. Apache, Apache Spark, Spark, the Spark Logo, Apache Iceberg, Iceberg, and the Apache Iceberg logo are trademarks of the <a href="https://www.apache.org/" target="_blank">Apache Software Foundation</a>.<br/><br/><a href="https://databricks.com/privacy-policy" target="_blank">Privacy Policy</a> | <a href="https://databricks.com/terms-of-use" target="_blank">Terms of Use</a> | <a href="https://help.databricks.com/" target="_blank">Support</a>
# MAGIC <script>
# MAGIC   document.getElementById("dbx-year").textContent = new Date().getFullYear();
# MAGIC </script>