-- Databricks notebook source
-- MAGIC %md-sandbox
-- MAGIC <div style="display:flex; align-items:center; padding:10px 18px; background:#F8F9FA; border-bottom:1px solid #E0E0E0; gap:10px;">
-- MAGIC   <img src="https://cdn.simpleicons.org/databricks/FF3621" width="22" height="22"/>
-- MAGIC   <div style="font-size:14px; color:#666; white-space:nowrap;">
-- MAGIC     <span style="font-weight:600; color:#333;">Academy</span>
-- MAGIC     <span style="margin:0 10px; color:#bbb;">|</span>
-- MAGIC     <span>UC Migration Delivery Specialization</span>
-- MAGIC     <span style="margin:0 10px; color:#bbb;">|</span>
-- MAGIC     <span>Setup</span>
-- MAGIC     <span style="margin:0 10px; color:#bbb;">|</span>
-- MAGIC     <span>Validation and Sign-off</span>
-- MAGIC     <span style="margin:0 10px; color:#bbb;">|</span>
-- MAGIC     <span style="font-weight:600; color:#eb1900;">Validate UC Connectivity</span>
-- MAGIC   </div>
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md
-- MAGIC <div style="text-align: center; line-height: 0; padding-top: 9px;">
-- MAGIC <img src="https://databricks.com/wp-content/uploads/2018/03/db-academy-rgb-1200px.png" alt="Databricks Learning">
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md
-- MAGIC # Validate UC Connectivity
-- MAGIC
-- MAGIC This notebook performs basic tests to validate UC connectivity.

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ## REQUIRED - SELECT A COMPUTE ENVIRONMENT
-- MAGIC
-- MAGIC <div style="
-- MAGIC   border-left: 4px solid #f44336;
-- MAGIC   background: #ffebee;
-- MAGIC   padding: 14px 18px;
-- MAGIC   border-radius: 4px;
-- MAGIC   margin: 16px 0;
-- MAGIC ">
-- MAGIC   <strong style="display:block; color:#c62828; margin-bottom:6px; font-size: 1.1em;">Select Serverless Compute</strong>
-- MAGIC   <div style="color:#333;">
-- MAGIC
-- MAGIC Before starting this notebook, select the required compute environment listed below.
-- MAGIC
-- MAGIC - **Serverless Compute, Version 4**  
-- MAGIC   - [How to select an environment version](https://docs.databricks.com/aws/en/compute/serverless/dependencies#-select-an-environment-version)
-- MAGIC
-- MAGIC **NOTE:**  This notebook was **developed and tested using Serverless V4**. Other compute options may work but are not guaranteed to behave the same or support all features demonstrated.
-- MAGIC   </div>
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Intercept parameters for `catalog_name`, `information_schema`, and `tables`, allowing test behaviour to be configured interactively or as part of a job.

-- COMMAND ----------

CREATE WIDGET TEXT catalog_name DEFAULT "main";
CREATE WIDGET TEXT schema_name DEFAULT "information_schema";
CREATE WIDGET TEXT table_name DEFAULT "tables";

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ## Test 1: Enumerate Catalogs
-- MAGIC In a UC metastore, there are a number of entries visible at the catalog level, including (but not limited to):
-- MAGIC - `hive_metastore`: a catalog connected to the legacy HMS
-- MAGIC - `main`: a default catalog created with each UC metastore
-- MAGIC - `samples`: sample datasets shared with each UC metastore
-- MAGIC - `system`: catalog containing system tables, a collection of views providing information about metastore objects
-- MAGIC In an HMS system (or compute resource with HMS-only visibility), only one catalog exists: spark_catalog, whereas with Unity Catalog, any number of entries can exist at the catalog level.
-- MAGIC - any other catalogs present for which the executing principal has `USE CATALOG`
-- MAGIC
-- MAGIC <div style="border-left: 4px solid #ff9800; background: #fff3e0; padding: 16px 20px; border-radius: 4px; margin: 16px 0;">
-- MAGIC   <div style="display: flex; align-items: center; gap: 12px;">
-- MAGIC     <span style="font-size: 24px;">⚠️</span>
-- MAGIC     <div>
-- MAGIC       In a legacy HMS system, only one catalog (<code>spark_catalog</code>) is reflected by this statement.
-- MAGIC     </div>
-- MAGIC   </div>
-- MAGIC </div>

-- COMMAND ----------

SHOW CATALOGS

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ## Test 2: Query Three-level Namespace
-- MAGIC In a UC metastore, we can directly address data objects using a three-level namespace. In this example, we attempt to query `main.information_schema.tables`; that is:
-- MAGIC - a view named `tables` (a view containing table metadata)
-- MAGIC - contained in the `information_schema` (a standard schema included in every catalog that provides a self-describing API for accessing metadata about schemas, tables, columns, and other database objects)
-- MAGIC - of the `main` catalog (a default catalog created with each metastore)
-- MAGIC
-- MAGIC <div style="border-left: 4px solid #ff9800; background: #fff3e0; padding: 16px 20px; border-radius: 4px; margin: 16px 0;">
-- MAGIC   <div style="display: flex; align-items: center; gap: 12px;">
-- MAGIC     <span style="font-size: 24px;">⚠️</span>
-- MAGIC     <div>
-- MAGIC       This query would immediately fail on a cluster with no UC visibility.
-- MAGIC     </div>
-- MAGIC   </div>
-- MAGIC </div>
-- MAGIC <div style="border-left: 4px solid #1976d2; background: #e3f2fd; padding: 16px 20px; border-radius: 4px; margin: 16px 0;">
-- MAGIC   <div style="display: flex; align-items: center; gap: 12px;">
-- MAGIC     <span style="font-size: 24px;">ℹ️</span>
-- MAGIC     <div>
-- MAGIC       This can be overridden with the <code>catalog_name</code>, <code>schema_name</code>, and <code>table_name</code> parameters, if you prefer to test against a specific catalog, schema and table/view that's been set up.
-- MAGIC     </div>
-- MAGIC   </div>
-- MAGIC </div>

-- COMMAND ----------

SELECT * FROM IDENTIFIER(:catalog_name || '.' || :schema_name || '.' || :table_name)

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC &copy; <span id="dbx-year"></span> Databricks, Inc. All rights reserved. Apache, Apache Spark, Spark, the Spark Logo, Apache Iceberg, Iceberg, and the Apache Iceberg logo are trademarks of the <a href="https://www.apache.org/" target="_blank">Apache Software Foundation</a>.<br/><br/><a href="https://databricks.com/privacy-policy" target="_blank">Privacy Policy</a> | <a href="https://databricks.com/terms-of-use" target="_blank">Terms of Use</a> | <a href="https://help.databricks.com/" target="_blank">Support</a>
-- MAGIC <script>
-- MAGIC   document.getElementById("dbx-year").textContent = new Date().getFullYear();
-- MAGIC </script>