-- Databricks notebook source
-- MAGIC %md-sandbox
-- MAGIC <div style="display:flex; align-items:center; padding:10px 18px; background:#F8F9FA; border-bottom:1px solid #E0E0E0; gap:10px;">
-- MAGIC   <img src="https://cdn.simpleicons.org/databricks/FF3621" width="22" height="22"/>
-- MAGIC   <div style="font-size:14px; color:#666; white-space:nowrap;">
-- MAGIC     <span style="font-weight:600; color:#333;">Academy</span>
-- MAGIC     <span style="margin:0 10px; color:#bbb;">|</span>
-- MAGIC     <span>Data Security & Governance Delivery Expert</span>
-- MAGIC     <span style="margin:0 10px; color:#bbb;">|</span>
-- MAGIC     <span>Design</span>
-- MAGIC     <span style="margin:0 10px; color:#bbb;">|</span>
-- MAGIC     <span style="font-weight:600; color:#eb1900;">Managing Identities</span>
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
-- MAGIC # Managing Identities
-- MAGIC
-- MAGIC Databricks gives you direct control over who can access workspaces, data, and compute resources—before any external identity provider (IdP) integration comes into play.
-- MAGIC
-- MAGIC Account admins and workspace admins are responsible for adding, updating, and deleting these identities. They can also assign admin and access roles, and manage group memberships to ensure proper governance.
-- MAGIC
-- MAGIC This demo reviews the procedures for managing identities in your Databricks Account and UC-enabled workspaces.
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
-- MAGIC - Manage users in the Databricks account
-- MAGIC - Manage assignments of users to workspaces

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## A. Account-level Management
-- MAGIC
-- MAGIC Account admins are responsible for the following tasks:
-- MAGIC 1. adding/removing users to/from the account, when this is not automated by an IdP
-- MAGIC 1. adding/removing service principals to/from the account
-- MAGIC 1. creating groups and configuring memberships when this is not automated by an IdP
-- MAGIC 1. delegating an admin for each workspace

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### A1. Managing Principals
-- MAGIC
-- MAGIC To add/remove users/service principals/groups, use the following steps:
-- MAGIC 1. In the **Account Console**, select **User Management** from the left sidebar.
-- MAGIC 1. Select the tab corresponding to the desired type (**Users**, **Service principals**, **Groups**).
-- MAGIC 1. From there, these types can be added, removed, or reconfigured.
-- MAGIC
-- MAGIC ![User Management Console](https://files.training.databricks.com/binder/prod_main/data-security-and-governance-en_us-1.1.0/images/20261012T073742Z/Data Security and Governance/02 - Design/Includes/images/account_console_user_management.png)

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### A2. Delegating Workspace Admins
-- MAGIC
-- MAGIC Since account admins also manage workspaces, they also need to delegate workspace admins.
-- MAGIC
-- MAGIC 1. In the **Account Console**, select **Workspaces** from the left sidebar.
-- MAGIC 1. Locate and select the desired workspace.
-- MAGIC 1. In the **Permissions** tab, perform one of the following:
-- MAGIC    - Promote an existing user by clicking the kebab menu in the far left of the row and setting their role to *Admin*, or
-- MAGIC    - Bring in a new user by clicking **Add permissions** and setting **Permission** to *Admin*.
-- MAGIC
-- MAGIC ![Workspace Permissions](https://files.training.databricks.com/binder/prod_main/data-security-and-governance-en_us-1.1.0/images/20261012T073742Z/Data Security and Governance/02 - Design/Includes/images/account_console_workspace_permissions.png)

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### A3. Enabling SCIM
-- MAGIC
-- MAGIC 1. In the **Account Console**, select **Security** from the left sidebar.
-- MAGIC 1. In the **User provisioning** tab:
-- MAGIC    - Generate a token
-- MAGIC    - Note the **Account SCIM URL**
-- MAGIC    - Supply both credentials to your IdP
-- MAGIC
-- MAGIC ![](https://files.training.databricks.com/binder/prod_main/data-security-and-governance-en_us-1.1.0/images/20261012T073742Z/Data Security and Governance/02 - Design/Includes/images/account_console_scim.png)

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## B. Workspace-level Management
-- MAGIC
-- MAGIC Workspace admins are responsible for the following tasks:
-- MAGIC 1. adding/removing account users, service principals, and groups to/from the workspace
-- MAGIC 1. sharing admin responsibilities with other users, if needed

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### B1. Managing Principals
-- MAGIC
-- MAGIC To add/remove users/service principals/groups, use the following steps:
-- MAGIC 1. Access the workspace admin console by clicking the user icon in the top-right corner, and selecting **Settings**.
-- MAGIC 1. Select **Identity and access** from the left sidebar.
-- MAGIC 1. Click the **Manage** button corresponding to the desired type (**Users**, **Service principals**, **Groups**).
-- MAGIC 1. From there, these types can be added, removed, or reconfigured.
-- MAGIC    - Workspace admin can be shared by promoting existing workspace users or service principals. This is done by enabling the **Admin access** entitlement.
-- MAGIC
-- MAGIC ![User Management Console](https://files.training.databricks.com/binder/prod_main/data-security-and-governance-en_us-1.1.0/images/20261012T073742Z/Data Security and Governance/02 - Design/Includes/images/workspace_admin_manage_users.png)

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC &copy; <span id="dbx-year"></span> Databricks, Inc. All rights reserved. Apache, Apache Spark, Spark, the Spark Logo, Apache Iceberg, Iceberg, and the Apache Iceberg logo are trademarks of the <a href="https://www.apache.org/" target="_blank">Apache Software Foundation</a>.<br/><br/><a href="https://databricks.com/privacy-policy" target="_blank">Privacy Policy</a> | <a href="https://databricks.com/terms-of-use" target="_blank">Terms of Use</a> | <a href="https://help.databricks.com/" target="_blank">Support</a>
-- MAGIC <script>
-- MAGIC   document.getElementById("dbx-year").textContent = new Date().getFullYear();
-- MAGIC </script>