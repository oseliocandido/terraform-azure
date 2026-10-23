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
# MAGIC     <span style="font-weight:600; color:#eb1900;">Cutover Execution</span>
# MAGIC   </div>
# MAGIC </div>

# COMMAND ----------

# MAGIC %md
# MAGIC <div style="text-align: center; line-height: 0; padding-top: 9px;">
# MAGIC <img src="https://databricks.com/wp-content/uploads/2018/03/db-academy-rgb-1200px.png" alt="Databricks Learning">
# MAGIC </div>

# COMMAND ----------

# MAGIC %md-sandbox
# MAGIC # Cutover Execution
# MAGIC
# MAGIC With migration complete and workloads running successfully on Unity Catalog, the final step is retiring the HMS and DBFS in all workspaces. This lesson covers the decommissioning process, including data archival, connector shutdown, and formal engagement closure.
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
# MAGIC - Execute a controlled HMS/DBFS decommissioning plan
# MAGIC - Archive tables, stages, and metadata for compliance
# MAGIC - Shut down connectors and integrations pointing to HMS
# MAGIC - Conduct final stakeholder review and close the migration engagement

# COMMAND ----------

# MAGIC %md-sandbox
# MAGIC ## A. Decommissioning Timeline
# MAGIC
# MAGIC Decommissioning should follow a phased approach with validation gates at each stage.
# MAGIC
# MAGIC <div style="display:flex; justify-content:center;">
# MAGIC <svg id="dsgsvg58" width="100%" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 784 220" style="display:block;margin-left:auto;margin-right:auto;font-family:Arial, Helvetica, sans-serif !important;max-width: 784px;" role="graphics-document document" aria-roledescription="gantt"><style>#dsgsvg58{font-family:Arial,Helvetica,sans-serif;font-size:16px;fill:#333;}@keyframes edge-animation-frame{from{stroke-dashoffset:0;}}@keyframes dash{to{stroke-dashoffset:0;}}#dsgsvg58 .edge-animation-slow{stroke-dasharray:9,5!important;stroke-dashoffset:900;animation:dash 50s linear infinite;stroke-linecap:round;}#dsgsvg58 .edge-animation-fast{stroke-dasharray:9,5!important;stroke-dashoffset:900;animation:dash 20s linear infinite;stroke-linecap:round;}#dsgsvg58 .error-icon{fill:#552222;}#dsgsvg58 .error-text{fill:#552222;stroke:#552222;}#dsgsvg58 .edge-thickness-normal{stroke-width:1px;}#dsgsvg58 .edge-thickness-thick{stroke-width:3.5px;}#dsgsvg58 .edge-pattern-solid{stroke-dasharray:0;}#dsgsvg58 .edge-thickness-invisible{stroke-width:0;fill:none;}#dsgsvg58 .edge-pattern-dashed{stroke-dasharray:3;}#dsgsvg58 .edge-pattern-dotted{stroke-dasharray:2;}#dsgsvg58 .marker{fill:#333333;stroke:#333333;}#dsgsvg58 .marker.cross{stroke:#333333;}#dsgsvg58 svg{font-family:Arial,Helvetica,sans-serif;font-size:16px;}#dsgsvg58 p{margin:0;}#dsgsvg58 .mermaid-main-font{font-family:Arial,Helvetica,sans-serif;}#dsgsvg58 .exclude-range{fill:#eeeeee;}#dsgsvg58 .section{stroke:none;opacity:0.2;}#dsgsvg58 .section0{fill:rgba(102, 102, 255, 0.49);}#dsgsvg58 .section2{fill:#fff400;}#dsgsvg58 .section1,#dsgsvg58 .section3{fill:white;opacity:0.2;}#dsgsvg58 .sectionTitle0{fill:#333;}#dsgsvg58 .sectionTitle1{fill:#333;}#dsgsvg58 .sectionTitle2{fill:#333;}#dsgsvg58 .sectionTitle3{fill:#333;}#dsgsvg58 .sectionTitle{text-anchor:start;font-family:Arial,Helvetica,sans-serif;}#dsgsvg58 .grid .tick{stroke:lightgrey;opacity:0.8;shape-rendering:crispEdges;}#dsgsvg58 .grid .tick text{font-family:Arial,Helvetica,sans-serif;fill:#333;}#dsgsvg58 .grid path{stroke-width:0;}#dsgsvg58 .today{fill:none;stroke:red;stroke-width:2px;}#dsgsvg58 .task{stroke-width:2;}#dsgsvg58 .taskText{text-anchor:middle;font-family:Arial,Helvetica,sans-serif;}#dsgsvg58 .taskTextOutsideRight{fill:black;text-anchor:start;font-family:Arial,Helvetica,sans-serif;}#dsgsvg58 .taskTextOutsideLeft{fill:black;text-anchor:end;}#dsgsvg58 .task.clickable{cursor:pointer;}#dsgsvg58 .taskText.clickable{cursor:pointer;fill:#003163!important;font-weight:bold;}#dsgsvg58 .taskTextOutsideLeft.clickable{cursor:pointer;fill:#003163!important;font-weight:bold;}#dsgsvg58 .taskTextOutsideRight.clickable{cursor:pointer;fill:#003163!important;font-weight:bold;}#dsgsvg58 .taskText0,#dsgsvg58 .taskText1,#dsgsvg58 .taskText2,#dsgsvg58 .taskText3{fill:white;}#dsgsvg58 .task0,#dsgsvg58 .task1,#dsgsvg58 .task2,#dsgsvg58 .task3{fill:#8a90dd;stroke:#534fbc;}#dsgsvg58 .taskTextOutside0,#dsgsvg58 .taskTextOutside2{fill:black;}#dsgsvg58 .taskTextOutside1,#dsgsvg58 .taskTextOutside3{fill:black;}#dsgsvg58 .active0,#dsgsvg58 .active1,#dsgsvg58 .active2,#dsgsvg58 .active3{fill:#bfc7ff;stroke:#534fbc;}#dsgsvg58 .activeText0,#dsgsvg58 .activeText1,#dsgsvg58 .activeText2,#dsgsvg58 .activeText3{fill:black!important;}#dsgsvg58 .done0,#dsgsvg58 .done1,#dsgsvg58 .done2,#dsgsvg58 .done3{stroke:grey;fill:lightgrey;stroke-width:2;}#dsgsvg58 .doneText0,#dsgsvg58 .doneText1,#dsgsvg58 .doneText2,#dsgsvg58 .doneText3{fill:black!important;}#dsgsvg58 .doneText0.taskTextOutsideLeft,#dsgsvg58 .doneText0.taskTextOutsideRight,#dsgsvg58 .doneText1.taskTextOutsideLeft,#dsgsvg58 .doneText1.taskTextOutsideRight,#dsgsvg58 .doneText2.taskTextOutsideLeft,#dsgsvg58 .doneText2.taskTextOutsideRight,#dsgsvg58 .doneText3.taskTextOutsideLeft,#dsgsvg58 .doneText3.taskTextOutsideRight{fill:black!important;}#dsgsvg58 .crit0,#dsgsvg58 .crit1,#dsgsvg58 .crit2,#dsgsvg58 .crit3{stroke:#ff8888;fill:red;stroke-width:2;}#dsgsvg58 .activeCrit0,#dsgsvg58 .activeCrit1,#dsgsvg58 .activeCrit2,#dsgsvg58 .activeCrit3{stroke:#ff8888;fill:#bfc7ff;stroke-width:2;}#dsgsvg58 .doneCrit0,#dsgsvg58 .doneCrit1,#dsgsvg58 .doneCrit2,#dsgsvg58 .doneCrit3{stroke:#ff8888;fill:lightgrey;stroke-width:2;cursor:pointer;shape-rendering:crispEdges;}#dsgsvg58 .milestone{transform:rotate(45deg) scale(0.8,0.8);}#dsgsvg58 .milestoneText{font-style:italic;}#dsgsvg58 .doneCritText0,#dsgsvg58 .doneCritText1,#dsgsvg58 .doneCritText2,#dsgsvg58 .doneCritText3{fill:black!important;}#dsgsvg58 .doneCritText0.taskTextOutsideLeft,#dsgsvg58 .doneCritText0.taskTextOutsideRight,#dsgsvg58 .doneCritText1.taskTextOutsideLeft,#dsgsvg58 .doneCritText1.taskTextOutsideRight,#dsgsvg58 .doneCritText2.taskTextOutsideLeft,#dsgsvg58 .doneCritText2.taskTextOutsideRight,#dsgsvg58 .doneCritText3.taskTextOutsideLeft,#dsgsvg58 .doneCritText3.taskTextOutsideRight{fill:black!important;}#dsgsvg58 .vert{stroke:navy;}#dsgsvg58 .vertText{font-size:15px;text-anchor:middle;fill:navy!important;}#dsgsvg58 .activeCritText0,#dsgsvg58 .activeCritText1,#dsgsvg58 .activeCritText2,#dsgsvg58 .activeCritText3{fill:black!important;}#dsgsvg58 .titleText{text-anchor:middle;font-size:18px;fill:#333;font-family:Arial,Helvetica,sans-serif;}#dsgsvg58 .node .neo-node{stroke:#9370DB;}#dsgsvg58 [data-look="neo"].node rect,#dsgsvg58 [data-look="neo"].cluster rect,#dsgsvg58 [data-look="neo"].node polygon{stroke:#9370DB;filter:drop-shadow(1px 2px 2px rgba(185, 185, 185, 1));}#dsgsvg58 [data-look="neo"].swimlane.cluster rect{filter:none;}#dsgsvg58 [data-look="neo"].node path{stroke:#9370DB;stroke-width:1px;}#dsgsvg58 [data-look="neo"].node .outer-path{filter:drop-shadow(1px 2px 2px rgba(185, 185, 185, 1));}#dsgsvg58 [data-look="neo"].node .neo-line path{stroke:#9370DB;filter:none;}#dsgsvg58 [data-look="neo"].node circle{stroke:#9370DB;filter:drop-shadow(1px 2px 2px rgba(185, 185, 185, 1));}#dsgsvg58 [data-look="neo"].node circle .state-start{fill:#000000;}#dsgsvg58 [data-look="neo"].icon-shape .icon{fill:#9370DB;filter:drop-shadow(1px 2px 2px rgba(185, 185, 185, 1));}#dsgsvg58 [data-look="neo"].icon-shape .icon-neo path{stroke:#9370DB;filter:drop-shadow(1px 2px 2px rgba(185, 185, 185, 1));}#dsgsvg58 :root{--mermaid-font-family:Arial,Helvetica,sans-serif;}</style><g></g><g class="grid" transform="translate(75, 170)" fill="none" font-size="10" font-family="sans-serif" text-anchor="middle"><path class="domain" stroke="currentColor" d="M0.5,-135V0.5H634.5V-135"></path><g class="tick" opacity="1" transform="translate(0.5,0)"><line stroke="currentColor" y2="-135"></line><text fill="#000" y="3" dy="1em" stroke="none" font-size="10" style="font-family:Arial, Helvetica, sans-serif !important;font-size:10px !important;text-anchor: middle;">00</text></g><g class="tick" opacity="1" transform="translate(127.5,0)"><line stroke="currentColor" y2="-135"></line><text fill="#000" y="3" dy="1em" stroke="none" font-size="10" style="font-family:Arial, Helvetica, sans-serif !important;font-size:10px !important;text-anchor: middle;">01</text></g><g class="tick" opacity="1" transform="translate(254.5,0)"><line stroke="currentColor" y2="-135"></line><text fill="#000" y="3" dy="1em" stroke="none" font-size="10" style="font-family:Arial, Helvetica, sans-serif !important;font-size:10px !important;text-anchor: middle;">02</text></g><g class="tick" opacity="1" transform="translate(380.5,0)"><line stroke="currentColor" y2="-135"></line><text fill="#000" y="3" dy="1em" stroke="none" font-size="10" style="font-family:Arial, Helvetica, sans-serif !important;font-size:10px !important;text-anchor: middle;">03</text></g><g class="tick" opacity="1" transform="translate(507.5,0)"><line stroke="currentColor" y2="-135"></line><text fill="#000" y="3" dy="1em" stroke="none" font-size="10" style="font-family:Arial, Helvetica, sans-serif !important;font-size:10px !important;text-anchor: middle;">04</text></g><g class="tick" opacity="1" transform="translate(634.5,0)"><line stroke="currentColor" y2="-135"></line><text fill="#000" y="3" dy="1em" stroke="none" font-size="10" style="font-family:Arial, Helvetica, sans-serif !important;font-size:10px !important;text-anchor: middle;">05</text></g></g><g><rect x="0" y="48" width="746.5" height="24" class="section section0"></rect><rect x="0" y="72" width="746.5" height="24" class="section section1"></rect><rect x="0" y="96" width="746.5" height="24" class="section section1"></rect><rect x="0" y="120" width="746.5" height="24" class="section section2"></rect><rect x="0" y="144" width="746.5" height="24" class="section section2"></rect></g><g><rect id="dsgsvg58-v1" rx="3" ry="3" x="75" y="50" width="127" height="20" transform-origin="138.5px 60px" class="task done0 "></rect><rect id="dsgsvg58-r1" rx="3" ry="3" x="202" y="74" width="253" height="20" transform-origin="328.5px 84px" class="task active1 "></rect><rect id="dsgsvg58-a1" rx="3" ry="3" x="455" y="98" width="127" height="20" transform-origin="518.5px 108px" class="task task1 "></rect><rect id="dsgsvg58-c1" rx="3" ry="3" x="582" y="122" width="127" height="20" transform-origin="645.5px 132px" class="task crit2 "></rect><rect id="dsgsvg58-s1" rx="3" ry="3" x="699" y="146" width="20" height="20" transform-origin="709px 156px" class="task milestone  task2 "></rect><text id="dsgsvg58-v1-text" font-size="11" x="138.5" y="63.5" text-height="20" class=" taskText taskText0  doneText0 width-80.09375" style="font-family:Arial, Helvetica, sans-serif !important;font-size:11px !important;">HMS Federation           </text><text id="dsgsvg58-r1-text" font-size="11" x="328.5" y="87.5" text-height="20" class=" taskText taskText1 activeText1 width-80.078125" style="font-family:Arial, Helvetica, sans-serif !important;font-size:11px !important;">HMS Read-Only                </text><text id="dsgsvg58-a1-text" font-size="11" x="518.5" y="111.5" text-height="20" class=" taskText taskText1  width-86.84423828125" style="font-family:Arial, Helvetica, sans-serif !important;font-size:11px !important;">Archive &amp; Backup                </text><text id="dsgsvg58-c1-text" font-size="11" x="645.5" y="135.5" text-height="20" class=" taskText taskText2  critText2 width-84.375" style="font-family:Arial, Helvetica, sans-serif !important;font-size:11px !important;">HMS Deprecated              </text><text id="dsgsvg58-s1-text" font-size="11" x="694" y="159.5" text-height="20" class=" taskTextOutsideLeft taskTextOutside2  milestoneText" style="font-family:Arial, Helvetica, sans-serif !important;font-size:11px !important;">HMS Disabled              </text></g><g><text dy="0em" x="10" y="62" font-size="11" class="sectionTitle sectionTitle0" style="font-family:Arial, Helvetica, sans-serif !important;font-size:11px !important;"><tspan alignment-baseline="central" x="10" style="font-family:Arial, Helvetica, sans-serif !important;font-size:11px !important;">Validation</tspan></text><text dy="0em" x="10" y="98" font-size="11" class="sectionTitle sectionTitle1" style="font-family:Arial, Helvetica, sans-serif !important;font-size:11px !important;"><tspan alignment-baseline="central" x="10" style="font-family:Arial, Helvetica, sans-serif !important;font-size:11px !important;">Wind-Down</tspan></text><text dy="0em" x="10" y="146" font-size="11" class="sectionTitle sectionTitle2" style="font-family:Arial, Helvetica, sans-serif !important;font-size:11px !important;"><tspan alignment-baseline="central" x="10" style="font-family:Arial, Helvetica, sans-serif !important;font-size:11px !important;">Shutdown</tspan></text></g><g class="today"><line x1="11659" x2="11659" y1="25" y2="195" class="today"></line></g><text x="392" y="25" class="titleText" style="font-family:Arial, Helvetica, sans-serif !important;font-size:18px !important;">HMS/DBFS Decommissioning Timeline</text></svg>
# MAGIC </div>
# MAGIC

# COMMAND ----------

# MAGIC %md
# MAGIC | Phase | Duration | Activities |
# MAGIC |-------|----------|------------|
# MAGIC | **Parallel Run Complete** | Week 0 | Confirm all workloads validated on UC |
# MAGIC | **Read-Only Period** | Weeks 1-2 | HMS set to read-only; monitor for access attempts |
# MAGIC | **Archive & Backup** | Week 3 | Export data, metadata, and query history |
# MAGIC | **HMS Deprecated** | Week 4 | Rename schemas |
# MAGIC | **HMS Disabled** | Week 5+ | Disable HMS from all workspaces; retain archives per policy |

# COMMAND ----------

# MAGIC %md
# MAGIC ## B. Pre-Decommission Validation
# MAGIC
# MAGIC Before beginning decommissioning, confirm all migration success criteria are met.
# MAGIC
# MAGIC | Validation | Owner |
# MAGIC |------------|-------|
# MAGIC | All tables migrated and row counts validated | Data Engineering |
# MAGIC | All pipelines running successfully on Databricks | Data Engineering |
# MAGIC | BI tools reconnected and dashboards functional | Analytics |
# MAGIC | Data quality monitors active with no critical alerts | Data Engineering |
# MAGIC | User acceptance testing signed off | Business Stakeholders |
# MAGIC | Performance SLAs met or exceeded | Data Engineering |
# MAGIC | Security and compliance review complete | Security |
# MAGIC | Runbooks and documentation delivered | Project Team |

# COMMAND ----------

# MAGIC %md
# MAGIC ## C. Archive and Backup
# MAGIC
# MAGIC Before deprecating HMS, archive critical data and metadata for compliance and potential rollback.
# MAGIC
# MAGIC ### What to Archive
# MAGIC
# MAGIC | Asset | Archive Method | Retention |
# MAGIC |-------|----------------|-----------|
# MAGIC | **Table data** | `COPY INTO` to cloud storage (Parquet) | Per data retention policy |
# MAGIC | **Stage contents** | Download or copy to archive bucket | 90 days minimum |
# MAGIC | **Query history** | Export from SQL warehouses | 1 year |
# MAGIC | **User/role definitions** | Export grants and role hierarchy | Permanent |

# COMMAND ----------

# MAGIC %md
# MAGIC ## D. Connector Shutdown
# MAGIC
# MAGIC Systematically disable all integrations pointing to HMS.
# MAGIC
# MAGIC | Integration Type | Shutdown Action |
# MAGIC |------------------|-----------------|
# MAGIC | **BI Tools** (Tableau, Power BI, Looker) | Remove any HMS connections; confirm UC connections active |
# MAGIC | **ETL/ELT Tools** (Fivetran, Airbyte, dbt) | Disable HMS destinations; verify UC targets |
# MAGIC | **Application connections** | Update connection strings; rotate credentials |
# MAGIC | **Scheduled tasks** | Suspend all jobs accessing HMS |
# MAGIC

# COMMAND ----------

# MAGIC %md-sandbox
# MAGIC <div style="border-left: 4px solid #ff9800; background: #fff3e0; padding: 16px 20px; border-radius: 8px; margin: 16px 0;">
# MAGIC     <div style="display: flex; align-items: flex-start; gap: 12px;">
# MAGIC         <span style="font-size: 24px;">⚠️</span>
# MAGIC         <div>
# MAGIC             <strong style="color: #e65100; font-size: 1.1em;">Monitor Before Shutdown</strong>
# MAGIC             <p style="margin: 8px 0 0 0; color: #333;">During the read-only period, monitor access logs to identify any overlooked integrations or users still attempting to connect. Address these before proceeding with deprecation.</p>
# MAGIC         </div>
# MAGIC     </div>
# MAGIC </div>

# COMMAND ----------

# MAGIC %md
# MAGIC ## E. Final Stakeholder Review
# MAGIC
# MAGIC Conduct a formal review with stakeholders to confirm migration success and close the engagement.
# MAGIC
# MAGIC ### Success Metrics to Present
# MAGIC
# MAGIC - Tables migrated and validated
# MAGIC - Pipelines operational on UC
# MAGIC - Performance comparison (HMS vs UC)
# MAGIC - User adoption and feedback

# COMMAND ----------

# MAGIC %md-sandbox
# MAGIC ## F. Recap
# MAGIC
# MAGIC <div style="border-left: 4px solid #4caf50; background: #e8f5e9; padding: 16px 20px; border-radius: 8px; margin: 16px 0;">
# MAGIC     <div style="display: flex; align-items: flex-start; gap: 12px;">
# MAGIC         <span style="font-size: 24px;">✅</span>
# MAGIC         <div>
# MAGIC             <strong style="color: #2e7d32; font-size: 1.1em;">Decommissioning Checklist</strong>
# MAGIC             <ul style="margin: 8px 0 0 0; color: #333; padding-left: 20px;">
# MAGIC                 <li>All migration success criteria validated</li>
# MAGIC                 <li>HMS data and metadata archived</li>
# MAGIC                 <li>Query and access history exported</li>
# MAGIC                 <li>All connectors and integrations disabled</li>
# MAGIC                 <li>Final stakeholder review completed</li>
# MAGIC                 <li>Sign-off obtained from business stakeholders</li>
# MAGIC                 <li>HMS disabled</li>
# MAGIC                 <li>Migration engagement formally closed</li>
# MAGIC             </ul>
# MAGIC         </div>
# MAGIC     </div>
# MAGIC </div>

# COMMAND ----------

# MAGIC %md-sandbox
# MAGIC &copy; <span id="dbx-year"></span> Databricks, Inc. All rights reserved. Apache, Apache Spark, Spark, the Spark Logo, Apache Iceberg, Iceberg, and the Apache Iceberg logo are trademarks of the <a href="https://www.apache.org/" target="_blank">Apache Software Foundation</a>.<br/><br/><a href="https://databricks.com/privacy-policy" target="_blank">Privacy Policy</a> | <a href="https://databricks.com/terms-of-use" target="_blank">Terms of Use</a> | <a href="https://help.databricks.com/" target="_blank">Support</a>
# MAGIC <script>
# MAGIC   document.getElementById("dbx-year").textContent = new Date().getFullYear();
# MAGIC </script>