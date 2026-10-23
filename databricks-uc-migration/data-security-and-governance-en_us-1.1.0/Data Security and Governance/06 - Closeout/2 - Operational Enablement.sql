-- Databricks notebook source
-- MAGIC %md-sandbox
-- MAGIC <div style="display:flex; align-items:center; padding:10px 18px; background:#F8F9FA; border-bottom:1px solid #E0E0E0; gap:10px;">
-- MAGIC   <img src="https://cdn.simpleicons.org/databricks/FF3621" width="22" height="22"/>
-- MAGIC   <div style="font-size:14px; color:#666; white-space:nowrap;">
-- MAGIC     <span style="font-weight:600; color:#333;">Academy</span>
-- MAGIC     <span style="margin:0 10px; color:#bbb;">|</span>
-- MAGIC     <span>Data Security & Governance Delivery Expert</span>
-- MAGIC     <span style="margin:0 10px; color:#bbb;">|</span>
-- MAGIC     <span>Closeout</span>
-- MAGIC     <span style="margin:0 10px; color:#bbb;">|</span>
-- MAGIC     <span style="font-weight:600; color:#eb1900;">Operational Enablement</span>
-- MAGIC   </div>
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md
-- MAGIC <div style="text-align: center; line-height: 0; padding-top: 9px;">
-- MAGIC <img src="https://databricks.com/wp-content/uploads/2018/03/db-academy-rgb-1200px.png" alt="Databricks Learning">
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC # Operational Enablement
-- MAGIC
-- MAGIC With migration complete and workloads running in production, this lesson focuses on establishing enterprise-grade observability. You will integrate Databricks with external monitoring platforms, configure notification destinations for alerting, and set up Data Profiling for ongoing data quality. This enables your operations team to monitor, troubleshoot, and optimize the platform as part of standard ITSM processes.
-- MAGIC
-- MAGIC ## Learning Objectives
-- MAGIC
-- MAGIC By the end of this lesson, you will be able to:
-- MAGIC
-- MAGIC - Integrate Databricks observability with enterprise monitoring tools (Splunk, Datadog, CloudWatch, Azure Monitor)
-- MAGIC - Configure Data Profiling for automated data quality and drift detection
-- MAGIC - Create operational dashboards for platform health, job performance, and cost tracking
-- MAGIC - Set up notification destinations (Slack, Teams, PagerDuty, email, webhooks) for alerting
-- MAGIC - Integrate Databricks into enterprise ITSM workflows for incident management
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

-- MAGIC %md-sandbox
-- MAGIC ## A. Enterprise Observability Architecture
-- MAGIC
-- MAGIC Post-migration observability integrates Databricks system tables and alerting capabilities with your existing enterprise tooling. The goal is to fit Databricks monitoring into your established ITSM processes rather than creating parallel workflows.
-- MAGIC
-- MAGIC <br/>
-- MAGIC <div style="display:flex; justify-content:center;">
-- MAGIC <svg id="dsgsvg59" width="100%" xmlns="http://www.w3.org/2000/svg" class="flowchart" style="display:block;margin-left:auto;margin-right:auto;font-family:Arial, Helvetica, sans-serif !important;max-width: 960.15625px;" viewBox="0 0 960.15625 230.3671875" role="graphics-document document" aria-roledescription="flowchart-v2"><style>#dsgsvg59{font-family:Arial,Helvetica,sans-serif;font-size:16px;fill:#333;}@keyframes edge-animation-frame{from{stroke-dashoffset:0;}}@keyframes dash{to{stroke-dashoffset:0;}}#dsgsvg59 .edge-animation-slow{stroke-dasharray:9,5!important;stroke-dashoffset:900;animation:dash 50s linear infinite;stroke-linecap:round;}#dsgsvg59 .edge-animation-fast{stroke-dasharray:9,5!important;stroke-dashoffset:900;animation:dash 20s linear infinite;stroke-linecap:round;}#dsgsvg59 .error-icon{fill:#552222;}#dsgsvg59 .error-text{fill:#552222;stroke:#552222;}#dsgsvg59 .edge-thickness-normal{stroke-width:1px;}#dsgsvg59 .edge-thickness-thick{stroke-width:3.5px;}#dsgsvg59 .edge-pattern-solid{stroke-dasharray:0;}#dsgsvg59 .edge-thickness-invisible{stroke-width:0;fill:none;}#dsgsvg59 .edge-pattern-dashed{stroke-dasharray:3;}#dsgsvg59 .edge-pattern-dotted{stroke-dasharray:2;}#dsgsvg59 .marker{fill:#333333;stroke:#333333;}#dsgsvg59 .marker.cross{stroke:#333333;}#dsgsvg59 svg{font-family:Arial,Helvetica,sans-serif;font-size:16px;}#dsgsvg59 p{margin:0;}#dsgsvg59 .label{font-family:Arial,Helvetica,sans-serif;color:#333;}#dsgsvg59 .cluster-label text{fill:#333;}#dsgsvg59 .cluster-label span{color:#333;}#dsgsvg59 .cluster-label span p{background-color:transparent;}#dsgsvg59 .label text,#dsgsvg59 span{fill:#333;color:#333;}#dsgsvg59 .node rect,#dsgsvg59 .node circle,#dsgsvg59 .node ellipse,#dsgsvg59 .node polygon,#dsgsvg59 .node path{fill:#ECECFF;stroke:#9370DB;stroke-width:1px;}#dsgsvg59 .rough-node .label text,#dsgsvg59 .node .label text,#dsgsvg59 .image-shape .label,#dsgsvg59 .icon-shape .label{text-anchor:middle;}#dsgsvg59 .node .katex path{fill:#000;stroke:#000;stroke-width:1px;}#dsgsvg59 .rough-node .label,#dsgsvg59 .node .label,#dsgsvg59 .image-shape .label,#dsgsvg59 .icon-shape .label{text-align:center;}#dsgsvg59 .node.clickable{cursor:pointer;}#dsgsvg59 .root .anchor path{fill:#333333!important;stroke-width:0;stroke:#333333;}#dsgsvg59 .arrowheadPath{fill:#333333;}#dsgsvg59 .edgePaths .path{stroke:#333333;stroke-width:1px;}#dsgsvg59 .flowchart-link{stroke:#333333;fill:none;}#dsgsvg59 .edgeLabel{background-color:rgba(232,232,232, 0.8);text-align:center;}#dsgsvg59 .edgeLabel p{background-color:rgba(232,232,232, 0.8);}#dsgsvg59 .edgeLabel rect{opacity:0.5;background-color:rgba(232,232,232, 0.8);fill:rgba(232,232,232, 0.8);}#dsgsvg59 .labelBkg{background-color:rgba(232, 232, 232, 0.5);}#dsgsvg59 .cluster rect{fill:#ffffde;stroke:#aaaa33;stroke-width:1px;}#dsgsvg59 .cluster text{fill:#333;}#dsgsvg59 .cluster span{color:#333;}#dsgsvg59 .node .collapsed-indicator{fill:#aaaa33;stroke:none;opacity:0.6;}#dsgsvg59 .node .collapsed-separator{stroke:#aaaa33;stroke-width:0.75px;}#dsgsvg59 div.mermaidTooltip{position:absolute;text-align:center;max-width:200px;padding:2px;font-family:Arial,Helvetica,sans-serif;font-size:12px;background:hsl(80, 100%, 96.2745098039%);border:1px solid #aaaa33;border-radius:2px;pointer-events:none;z-index:100;}#dsgsvg59 .flowchartTitleText{text-anchor:middle;font-size:18px;fill:#333;}#dsgsvg59 rect.text{fill:none;stroke-width:0;}#dsgsvg59 .icon-shape,#dsgsvg59 .image-shape{background-color:rgba(232,232,232, 0.8);text-align:center;}#dsgsvg59 .icon-shape p,#dsgsvg59 .image-shape p{background-color:rgba(232,232,232, 0.8);padding:2px;}#dsgsvg59 .icon-shape .label rect,#dsgsvg59 .image-shape .label rect{opacity:0.5;background-color:rgba(232,232,232, 0.8);fill:rgba(232,232,232, 0.8);}#dsgsvg59 .label-icon{display:inline-block;height:1em;overflow:visible;vertical-align:-0.125em;}#dsgsvg59 .node .label-icon path{fill:currentColor;stroke:revert;stroke-width:revert;}#dsgsvg59 .node .neo-node{stroke:#9370DB;}#dsgsvg59 [data-look="neo"].node rect,#dsgsvg59 [data-look="neo"].cluster rect,#dsgsvg59 [data-look="neo"].node polygon{stroke:#9370DB;filter:drop-shadow(1px 2px 2px rgba(185, 185, 185, 1));}#dsgsvg59 [data-look="neo"].swimlane.cluster rect{filter:none;}#dsgsvg59 [data-look="neo"].node path{stroke:#9370DB;stroke-width:1px;}#dsgsvg59 [data-look="neo"].node .outer-path{filter:drop-shadow(1px 2px 2px rgba(185, 185, 185, 1));}#dsgsvg59 [data-look="neo"].node .neo-line path{stroke:#9370DB;filter:none;}#dsgsvg59 [data-look="neo"].node circle{stroke:#9370DB;filter:drop-shadow(1px 2px 2px rgba(185, 185, 185, 1));}#dsgsvg59 [data-look="neo"].node circle .state-start{fill:#000000;}#dsgsvg59 [data-look="neo"].icon-shape .icon{fill:#9370DB;filter:drop-shadow(1px 2px 2px rgba(185, 185, 185, 1));}#dsgsvg59 [data-look="neo"].icon-shape .icon-neo path{stroke:#9370DB;filter:drop-shadow(1px 2px 2px rgba(185, 185, 185, 1));}#dsgsvg59 :root{--mermaid-font-family:Arial,Helvetica,sans-serif;}</style><g><marker id="dsgsvg59_flowchart-v2-pointEnd" class="marker flowchart-v2" viewBox="0 0 10 10" refX="5" refY="5" markerUnits="userSpaceOnUse" markerWidth="8" markerHeight="8" orient="auto"><path d="M 0 0 L 10 5 L 0 10 z" class="arrowMarkerPath" style="stroke-width: 1; stroke-dasharray: 1, 0;"></path></marker><marker id="dsgsvg59_flowchart-v2-pointStart" class="marker flowchart-v2" viewBox="0 0 10 10" refX="4.5" refY="5" markerUnits="userSpaceOnUse" markerWidth="8" markerHeight="8" orient="auto"><path d="M 0 5 L 10 10 L 10 0 z" class="arrowMarkerPath" style="stroke-width: 1; stroke-dasharray: 1, 0;"></path></marker><marker id="dsgsvg59_flowchart-v2-pointEnd-margin" class="marker flowchart-v2" viewBox="0 0 11.5 14" refX="11.5" refY="7" markerUnits="userSpaceOnUse" markerWidth="10.5" markerHeight="14" orient="auto"><path d="M 0 0 L 11.5 7 L 0 14 z" class="arrowMarkerPath" style="stroke-width: 0; stroke-dasharray: 1, 0;"></path></marker><marker id="dsgsvg59_flowchart-v2-pointStart-margin" class="marker flowchart-v2" viewBox="0 0 11.5 14" refX="1" refY="7" markerUnits="userSpaceOnUse" markerWidth="11.5" markerHeight="14" orient="auto"><polygon points="0,7 11.5,14 11.5,0" class="arrowMarkerPath" style="stroke-width: 0; stroke-dasharray: 1, 0;"></polygon></marker><marker id="dsgsvg59_flowchart-v2-circleEnd" class="marker flowchart-v2" viewBox="0 0 10 10" refX="11" refY="5" markerUnits="userSpaceOnUse" markerWidth="11" markerHeight="11" orient="auto"><circle cx="5" cy="5" r="5" class="arrowMarkerPath" style="stroke-width: 1; stroke-dasharray: 1, 0;"></circle></marker><marker id="dsgsvg59_flowchart-v2-circleStart" class="marker flowchart-v2" viewBox="0 0 10 10" refX="-1" refY="5" markerUnits="userSpaceOnUse" markerWidth="11" markerHeight="11" orient="auto"><circle cx="5" cy="5" r="5" class="arrowMarkerPath" style="stroke-width: 1; stroke-dasharray: 1, 0;"></circle></marker><marker id="dsgsvg59_flowchart-v2-circleEnd-margin" class="marker flowchart-v2" viewBox="0 0 10 10" refY="5" refX="12.25" markerUnits="userSpaceOnUse" markerWidth="14" markerHeight="14" orient="auto"><circle cx="5" cy="5" r="5" class="arrowMarkerPath" style="stroke-width: 0; stroke-dasharray: 1, 0;"></circle></marker><marker id="dsgsvg59_flowchart-v2-circleStart-margin" class="marker flowchart-v2" viewBox="0 0 10 10" refX="-2" refY="5" markerUnits="userSpaceOnUse" markerWidth="14" markerHeight="14" orient="auto"><circle cx="5" cy="5" r="5" class="arrowMarkerPath" style="stroke-width: 0; stroke-dasharray: 1, 0;"></circle></marker><marker id="dsgsvg59_flowchart-v2-crossEnd" class="marker cross flowchart-v2" viewBox="0 0 11 11" refX="12" refY="5.2" markerUnits="userSpaceOnUse" markerWidth="11" markerHeight="11" orient="auto"><path d="M 1,1 l 9,9 M 10,1 l -9,9" class="arrowMarkerPath" style="stroke-width: 2; stroke-dasharray: 1, 0;"></path></marker><marker id="dsgsvg59_flowchart-v2-crossStart" class="marker cross flowchart-v2" viewBox="0 0 11 11" refX="-1" refY="5.2" markerUnits="userSpaceOnUse" markerWidth="11" markerHeight="11" orient="auto"><path d="M 1,1 l 9,9 M 10,1 l -9,9" class="arrowMarkerPath" style="stroke-width: 2; stroke-dasharray: 1, 0;"></path></marker><marker id="dsgsvg59_flowchart-v2-crossEnd-margin" class="marker cross flowchart-v2" viewBox="0 0 15 15" refX="17.7" refY="7.5" markerUnits="userSpaceOnUse" markerWidth="12" markerHeight="12" orient="auto"><path d="M 1,1 L 14,14 M 1,14 L 14,1" class="arrowMarkerPath" style="stroke-width: 2.5;"></path></marker><marker id="dsgsvg59_flowchart-v2-crossStart-margin" class="marker cross flowchart-v2" viewBox="0 0 15 15" refX="-3.5" refY="7.5" markerUnits="userSpaceOnUse" markerWidth="12" markerHeight="12" orient="auto"><path d="M 1,1 L 14,14 M 1,14 L 14,1" class="arrowMarkerPath" style="stroke-width: 2.5; stroke-dasharray: 1, 0;"></path></marker><g class="root"><g class="clusters"><g class="cluster " id="dsgsvg59-OPS" data-look="classic"><rect style="fill:#e8f5e9 !important;stroke:#4caf50 !important;stroke-width:2px !important" x="690.109375" y="17.158203125" width="262.046875" height="185.8671875"></rect><g class="cluster-label " transform="translate(782, 17.158203125)"><g><rect class="background" style="stroke: none"></rect><text y="-10.1" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"><tspan class="text-outer-tspan row" x="0" y="-0.1em" dy="1.1em" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"><tspan font-style="normal" class="text-inner-tspan" font-weight="normal" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;">Operations</tspan></tspan></text></g></g></g><g class="cluster " id="dsgsvg59-ENT" data-look="classic"><rect style="fill:#e3f2fd !important;stroke:#2196f3 !important;stroke-width:2px !important" x="378.90625" y="8" width="261.203125" height="214.3671875"></rect><g class="cluster-label " transform="translate(445.6171875, 8)"><g><rect class="background" style="stroke: none"></rect><text y="-10.1" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"><tspan class="text-outer-tspan row" x="0" y="-0.1em" dy="1.1em" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"><tspan font-style="normal" class="text-inner-tspan" font-weight="normal" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;">Enterprise</tspan><tspan font-style="normal" class="text-inner-tspan" font-weight="normal" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"> Tooling</tspan></tspan></text></g></g></g><g class="cluster " id="dsgsvg59-DBX" data-look="classic"><rect style="fill:#ffe0b2 !important;stroke:#FF3621 !important;stroke-width:2px !important" x="8" y="8" width="213.75" height="214.3671875"></rect><g class="cluster-label " transform="translate(77.0859375, 8)"><g><rect class="background" style="stroke: none"></rect><text y="-10.1" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"><tspan class="text-outer-tspan row" x="0" y="-0.1em" dy="1.1em" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"><tspan font-style="normal" class="text-inner-tspan" font-weight="normal" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;">Databricks</tspan></tspan></text></g></g></g></g><g class="edgePaths"><path d="M196.75,163.684L200.917,163.684C205.083,163.684,213.417,163.684,230.68,163.684C247.943,163.684,274.135,163.684,300.328,163.684C326.521,163.684,352.714,163.684,370.35,163.684C387.987,163.684,397.068,163.684,401.608,163.684L406.148,163.684" id="dsgsvg59-L_SYS_MON_0" class=" edge-thickness-normal edge-pattern-solid edge-thickness-normal edge-pattern-solid flowchart-link" style=";" data-edge="true" data-et="edge" data-id="L_SYS_MON_0" data-points="W3sieCI6MTk2Ljc1LCJ5IjoxNjMuNjgzNTkzNzV9LHsieCI6MjIxLjc1LCJ5IjoxNjMuNjgzNTkzNzV9LHsieCI6MzAwLjMyODEyNSwieSI6MTYzLjY4MzU5Mzc1fSx7IngiOjM3OC45MDYyNSwieSI6MTYzLjY4MzU5Mzc1fSx7IngiOjQxMC4xNDg0Mzc1LCJ5IjoxNjMuNjgzNTkzNzV9XQ==" data-look="classic" marker-end="url(#dsgsvg59_flowchart-v2-pointEnd)"></path><path d="M182.82,66.5L189.309,66.5C195.797,66.5,208.773,66.5,228.358,66.5C247.943,66.5,274.135,66.5,300.328,66.5C326.521,66.5,352.714,66.5,369.31,66.5C385.906,66.5,392.906,66.5,396.406,66.5L399.906,66.5" id="dsgsvg59-L_ALRT_NOTIFY_0" class=" edge-thickness-normal edge-pattern-solid edge-thickness-normal edge-pattern-solid flowchart-link" style=";" data-edge="true" data-et="edge" data-id="L_ALRT_NOTIFY_0" data-points="W3sieCI6MTgyLjgyMDMxMjUsInkiOjY2LjV9LHsieCI6MjIxLjc1LCJ5Ijo2Ni41fSx7IngiOjMwMC4zMjgxMjUsInkiOjY2LjV9LHsieCI6Mzc4LjkwNjI1LCJ5Ijo2Ni41fSx7IngiOjQwMy45MDYyNSwieSI6NjYuNX1d" data-look="classic" marker-end="url(#dsgsvg59_flowchart-v2-pointEnd)"></path><path d="M615.109,66.5L619.276,66.5C623.443,66.5,631.776,66.5,640.109,66.5C648.443,66.5,656.776,66.5,665.109,66.5C673.443,66.5,681.776,66.5,696.511,70.42C711.247,74.339,732.384,82.178,742.953,86.098L753.522,90.017" id="dsgsvg59-L_NOTIFY_ITSM_0" class=" edge-thickness-normal edge-pattern-solid edge-thickness-normal edge-pattern-solid flowchart-link" style=";" data-edge="true" data-et="edge" data-id="L_NOTIFY_ITSM_0" data-points="W3sieCI6NjE1LjEwOTM3NSwieSI6NjYuNX0seyJ4Ijo2NDAuMTA5Mzc1LCJ5Ijo2Ni41fSx7IngiOjY2NS4xMDkzNzUsInkiOjY2LjV9LHsieCI6NjkwLjEwOTM3NSwieSI6NjYuNX0seyJ4Ijo3NTcuMjcyMTE4NjE2NjA0NCwieSI6OTEuNDA4MjAzMTI1fV0=" data-look="classic" marker-end="url(#dsgsvg59_flowchart-v2-pointEnd)"></path><path d="M608.867,163.684L614.074,163.684C619.281,163.684,629.695,163.684,639.069,163.684C648.443,163.684,656.776,163.684,665.109,163.684C673.443,163.684,681.776,163.684,696.511,159.764C711.247,155.844,732.384,148.005,742.953,144.086L753.522,140.166" id="dsgsvg59-L_MON_ITSM_0" class=" edge-thickness-normal edge-pattern-solid edge-thickness-normal edge-pattern-solid flowchart-link" style=";" data-edge="true" data-et="edge" data-id="L_MON_ITSM_0" data-points="W3sieCI6NjA4Ljg2NzE4NzUsInkiOjE2My42ODM1OTM3NX0seyJ4Ijo2NDAuMTA5Mzc1LCJ5IjoxNjMuNjgzNTkzNzV9LHsieCI6NjY1LjEwOTM3NSwieSI6MTYzLjY4MzU5Mzc1fSx7IngiOjY5MC4xMDkzNzUsInkiOjE2My42ODM1OTM3NX0seyJ4Ijo3NTcuMjcyMTE4NjE2NjA0NCwieSI6MTM4Ljc3NTM5MDYyNX1d" data-look="classic" marker-end="url(#dsgsvg59_flowchart-v2-pointEnd)"></path></g><g class="edgeLabels"><g class="edgeLabel" transform="translate(300.4020080566406, 163.6840057373047)"><g class="label" data-id="L_SYS_MON_0" transform="translate(0, 0)"><g><rect class="background" style="opacity:1 !important;fill:#F4F4F4 !important;stroke:none;" x="-57.57331466674805" y="-12.185599327087402" width="115.1466293334961" height="24.371198654174805" rx="3"></rect><text y="-10.1" text-anchor="middle" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;" transform="translate(0, -10.488639950752258)"><tspan class="text-outer-tspan row" x="0" y="-0.1em" dy="1.1em" text-anchor="middle" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"><tspan font-style="normal" class="text-inner-tspan" font-weight="normal" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;">Export</tspan><tspan font-style="normal" class="text-inner-tspan" font-weight="normal" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"> /</tspan><tspan font-style="normal" class="text-inner-tspan" font-weight="normal" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"> Query</tspan></tspan></text></g></g></g><g class="edgeLabel"><g class="label" data-id="L_ALRT_NOTIFY_0" transform="translate(0, 0)"><text y="-10.1" text-anchor="middle" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"><tspan class="text-outer-tspan row" x="0" y="-0.1em" dy="1.1em" text-anchor="middle" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"></tspan></text></g></g><g><rect class="background" style="stroke: none"></rect></g><g class="edgeLabel"><g class="label" data-id="L_NOTIFY_ITSM_0" transform="translate(0, 0)"><text y="-10.1" text-anchor="middle" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"><tspan class="text-outer-tspan row" x="0" y="-0.1em" dy="1.1em" text-anchor="middle" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"></tspan></text></g></g><g><rect class="background" style="stroke: none"></rect></g><g class="edgeLabel"><g class="label" data-id="L_MON_ITSM_0" transform="translate(0, 0)"><text y="-10.1" text-anchor="middle" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"><tspan class="text-outer-tspan row" x="0" y="-0.1em" dy="1.1em" text-anchor="middle" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"></tspan></text></g></g><g><rect class="background" style="stroke: none"></rect></g></g><g class="nodes"><g class="node default  " id="dsgsvg59-flowchart-SYS-0" data-look="classic" transform="translate(114.875, 163.68359375)"><rect class="basic label-container" style="" x="-81.875" y="-23.68359375" width="163.75" height="47.3671875"></rect><g class="label" style="" transform="translate(0, -8.68359375)"><rect></rect><g><rect class="background" style="stroke: none"></rect><text y="-10.1" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"><tspan class="text-outer-tspan row" x="0" y="-0.1em" dy="1.1em" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"><tspan font-style="normal" class="text-inner-tspan" font-weight="normal" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;">System</tspan><tspan font-style="normal" class="text-inner-tspan" font-weight="normal" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"> Tables</tspan></tspan></text></g></g></g><g class="node default  " id="dsgsvg59-flowchart-ALRT-1" data-look="classic" transform="translate(114.875, 66.5)"><rect class="basic label-container" style="" x="-67.9453125" y="-23.5" width="135.890625" height="47"></rect><g class="label" style="" transform="translate(0, -8.5)"><rect></rect><g><rect class="background" style="stroke: none"></rect><text y="-10.1" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"><tspan class="text-outer-tspan row" x="0" y="-0.1em" dy="1.1em" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"><tspan font-style="normal" class="text-inner-tspan" font-weight="normal" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;">SQL</tspan><tspan font-style="normal" class="text-inner-tspan" font-weight="normal" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"> Alerts</tspan></tspan></text></g></g></g><g class="node default  " id="dsgsvg59-flowchart-MON-2" data-look="classic" transform="translate(509.5078125, 163.68359375)"><rect class="basic label-container" style="" x="-99.359375" y="-23.68359375" width="198.71875" height="47.3671875"></rect><g class="label" style="" transform="translate(0, -8.68359375)"><rect></rect><g><rect class="background" style="stroke: none"></rect><text y="-10.1" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"><tspan class="text-outer-tspan row" x="0" y="-0.1em" dy="1.1em" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"><tspan font-style="normal" class="text-inner-tspan" font-weight="normal" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;">Monitoring</tspan><tspan font-style="normal" class="text-inner-tspan" font-weight="normal" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"> Platform</tspan></tspan></text></g></g></g><g class="node default  " id="dsgsvg59-flowchart-NOTIFY-3" data-look="classic" transform="translate(509.5078125, 66.5)"><rect class="basic label-container" style="" x="-105.6015625" y="-23.5" width="211.203125" height="47"></rect><g class="label" style="" transform="translate(0, -8.5)"><rect></rect><g><rect class="background" style="stroke: none"></rect><text y="-10.1" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"><tspan class="text-outer-tspan row" x="0" y="-0.1em" dy="1.1em" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"><tspan font-style="normal" class="text-inner-tspan" font-weight="normal" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;">Notification</tspan><tspan font-style="normal" class="text-inner-tspan" font-weight="normal" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"> Channels</tspan></tspan></text></g></g></g><g class="node default  " id="dsgsvg59-flowchart-ITSM-4" data-look="classic" transform="translate(821.1328125, 115.091796875)"><rect class="basic label-container" style="" x="-106.0234375" y="-23.68359375" width="212.046875" height="47.3671875"></rect><g class="label" style="" transform="translate(0, -8.68359375)"><rect></rect><g><rect class="background" style="stroke: none"></rect><text y="-10.1" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"><tspan class="text-outer-tspan row" x="0" y="-0.1em" dy="1.1em" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"><tspan font-style="normal" class="text-inner-tspan" font-weight="normal" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;">ITSM</tspan><tspan font-style="normal" class="text-inner-tspan" font-weight="normal" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"> /</tspan><tspan font-style="normal" class="text-inner-tspan" font-weight="normal" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"> Incident</tspan><tspan font-style="normal" class="text-inner-tspan" font-weight="normal" style="font-family:Arial, Helvetica, sans-serif !important;font-size:16px !important;"> Mgmt</tspan></tspan></text></g></g></g></g></g></g><defs><filter id="dsgsvg59-drop-shadow" height="130%" width="130%"><feDropShadow dx="4" dy="4" stdDeviation="0" flood-opacity="0.06" flood-color="#000000"></feDropShadow></filter></defs><defs><filter id="dsgsvg59-drop-shadow-small" height="150%" width="150%"><feDropShadow dx="2" dy="2" stdDeviation="0" flood-opacity="0.06" flood-color="#000000"></feDropShadow></filter></defs></svg>
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## B. System Tables for Observability
-- MAGIC
-- MAGIC System tables provide the foundation for all observability in Databricks. These tables can be queried directly, exported to external systems, or used to power dashboards and alerts.
-- MAGIC
-- MAGIC | Schema | Key Tables | Use Case |
-- MAGIC |--------|------------|----------|
-- MAGIC | `system.billing` | `usage`, `list_prices` | Cost dashboards, chargeback reports, budget alerts |
-- MAGIC | `system.lakeflow` | `jobs`, `job_tasks`, `job_task_run_timeline`, `pipelines` | Job SLA monitoring, failure alerting |
-- MAGIC | `system.compute` | `clusters`, `warehouse_events` | Capacity planning, utilization trending |
-- MAGIC | `system.access` | `audit`, `table_lineage` | Security monitoring, compliance reporting |
-- MAGIC | `system.query` | `history` | Performance analysis, slow query detection |

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC <div style="border-left: 4px solid #1976d2; background: #e3f2fd; padding: 16px 20px; border-radius: 8px; margin: 16px 0;">
-- MAGIC     <div style="display: flex; align-items: flex-start; gap: 12px;">
-- MAGIC         <span style="font-size: 24px;">ℹ️</span>
-- MAGIC         <div>
-- MAGIC             <strong style="color: #0d47a1; font-size: 1.1em;">System Table Data Retention</strong>
-- MAGIC             <p style="margin: 8px 0 0 0; color: #333;">System tables retain data for varying periods: billing data for 365 days, audit logs for 365 days, query history for 30 days, and job runs for 60 days. For long-term retention, configure scheduled exports to your enterprise data lake or SIEM platform.</p>
-- MAGIC         </div>
-- MAGIC     </div>
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## C. Enterprise Monitoring Integration
-- MAGIC
-- MAGIC Export Databricks metrics to your existing enterprise monitoring platforms for unified observability. The general pattern involves querying system tables on a schedule and pushing data to your monitoring platform via their ingestion APIs.
-- MAGIC
-- MAGIC ### Integration Patterns by Platform
-- MAGIC
-- MAGIC | Platform | Integration Method | Data Sources |
-- MAGIC |----------|-------------------|--------------|
-- MAGIC | **Datadog** | Datadog Agent on clusters, API export | Spark metrics, system tables |
-- MAGIC | **Splunk** | HTTP Event Collector (HEC), scheduled export | Audit logs, job events, query history |
-- MAGIC | **AWS CloudWatch** | CloudWatch Agent, custom metrics API | Cluster metrics, job telemetry |
-- MAGIC | **Azure Monitor** | Diagnostic settings, Log Analytics | Workspace logs, billing data |
-- MAGIC | **New Relic** | OTLP export, custom integration | Spark metrics, job telemetry |

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC <div style="border-left: 4px solid #009688; background: #e0f2f1; padding: 16px 20px; border-radius: 8px; margin: 16px 0;">
-- MAGIC     <div style="display: flex; align-items: flex-start; gap: 12px;">
-- MAGIC         <span style="font-size: 24px;">💡</span>
-- MAGIC         <div>
-- MAGIC             <strong style="color: #00695c; font-size: 1.1em;">Integration Approach</strong>
-- MAGIC             <p style="margin: 8px 0 0 0; color: #333;">Most integrations follow a common pattern: create a scheduled Databricks job that queries system tables, transforms the data into the target platform's format, and pushes it via API (e.g., Splunk HEC, CloudWatch PutMetricData, Datadog API). Use Databricks Secrets to store API keys securely.</p>
-- MAGIC         </div>
-- MAGIC     </div>
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## D. Notification Destinations and SQL Alerts
-- MAGIC
-- MAGIC Databricks supports multiple notification destinations for SQL Alerts, job notifications, and pipeline alerts. Configure these to integrate with your existing communication and incident management tools.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### D1. Supported Notification Destinations
-- MAGIC
-- MAGIC | Destination | Use Case | Configuration |
-- MAGIC |-------------|----------|---------------|
-- MAGIC | **Email** | Individual notifications, distribution lists | Built-in, configure recipients |
-- MAGIC | **Slack** | Team channels, ChatOps | Webhook URL or Slack app |
-- MAGIC | **Microsoft Teams** | Enterprise communication | Incoming webhook connector |
-- MAGIC | **PagerDuty** | On-call escalation, incident management | Integration key |
-- MAGIC | **Webhook** | Custom integrations (ServiceNow, Jira, etc.) | HTTP endpoint URL |
-- MAGIC
-- MAGIC Notification destinations are configured at the workspace level via **Settings -> Notification destinations** or programmatically via the Databricks CLI/API.

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ### D2. SQL Alerts
-- MAGIC
-- MAGIC SQL Alerts evaluate queries on a schedule and trigger notifications when conditions are met. Use these for proactive monitoring of job failures, data quality issues, SLA breaches, and cost anomalies.
-- MAGIC
-- MAGIC **To create an alert:** Save a query, click the three-dot menu, select "Create Alert", configure the schedule and trigger condition, then assign notification destinations.
-- MAGIC
-- MAGIC #### Example Alert Query
-- MAGIC
-- MAGIC SQL query reporting job failures in the last hour:
-- MAGIC <pre><code class="language-sql">SELECT 
-- MAGIC     j.name AS job_name,
-- MAGIC     COUNT(*) AS failure_count,
-- MAGIC     MAX(r.period_end_time) AS last_failure
-- MAGIC FROM system.lakeflow.job_run_timeline r
-- MAGIC JOIN system.lakeflow.jobs j ON r.job_id = j.job_id
-- MAGIC WHERE r.result_state = 'FAILED'
-- MAGIC   AND r.period_end_time >= current_timestamp() - INTERVAL 1 HOUR
-- MAGIC GROUP BY j.name
-- MAGIC HAVING COUNT(*) > 0
-- MAGIC ORDER BY failure_count DESC;
-- MAGIC </code></pre>
-- MAGIC
-- MAGIC <link href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/themes/prism.min.css" rel="stylesheet" />
-- MAGIC <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/prism.min.js"></script>
-- MAGIC <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-sql.min.js"></script>

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## E. Data Profiling
-- MAGIC
-- MAGIC Data Profiling provides automated data quality monitoring, drift detection, and statistical profiling for your tables.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### E1. Key Capabilities
-- MAGIC
-- MAGIC | Feature | Description |
-- MAGIC |---------|-------------|
-- MAGIC | **Profile Metrics** | Automated statistics (null counts, distinct values, distributions) captured on schedule |
-- MAGIC | **Drift Detection** | Compares current data against baseline to detect schema and data drift |
-- MAGIC | **Custom Metrics** | Define business-specific quality metrics using SQL expressions |
-- MAGIC | **Inference Tables** | Monitor ML model inputs and outputs for prediction drift |
-- MAGIC | **Alert Integration** | Trigger alerts when metrics breach thresholds |

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ### E2. Setting Up Monitors
-- MAGIC
-- MAGIC Lakehouse Monitors are configured via the Catalog Explorer UI (**Catalog -> Select table -> Quality tab -> Create monitor**) or programmatically via the Databricks SDK. When a monitor is created, Databricks automatically generates profile and drift metrics tables in your specified output schema.
-- MAGIC
-- MAGIC <div style="border-left: 4px solid #ff9800; background: #fff3e0; padding: 16px 20px; border-radius: 8px; margin: 16px 0;">
-- MAGIC     <div style="display: flex; align-items: flex-start; gap: 12px;">
-- MAGIC         <span style="font-size: 24px;">⚠️</span>
-- MAGIC         <div>
-- MAGIC             <strong style="color: #e65100; font-size: 1.1em;">Monitor Configuration</strong>
-- MAGIC             <p style="margin: 8px 0 0 0; color: #333;">Data Profiling requires a Unity Catalog-enabled workspace and a SQL Warehouse for metric computation. Configure monitors on your most critical tables first-those that feed dashboards, reports, or ML models-and expand coverage over time.</p>
-- MAGIC         </div>
-- MAGIC     </div>
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## F. Operational Dashboards
-- MAGIC
-- MAGIC Create AI/BI Dashboards for centralized visibility into platform health, job performance, and costs. These dashboards support daily operations and stakeholder reporting. All dashboard queries can be built from system tables.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### F1. Recommended Dashboards
-- MAGIC
-- MAGIC | Dashboard | Key Metrics | Refresh Schedule |
-- MAGIC |-----------|------------|------------------|
-- MAGIC | **Platform Health** | Active clusters, warehouse utilization, error rates | 5 minutes |
-- MAGIC | **Job Performance** | Success rates, SLA compliance, failure trends | 15 minutes |
-- MAGIC | **Data Quality** | Monitor drift scores, freshness, expectation failures | Hourly |
-- MAGIC | **Cost Tracking** | Daily DBU consumption, team attribution, budget status | Daily |

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC #### F1.1 Example Dashboard Query
-- MAGIC
-- MAGIC The following SQL query provides a summary over the last 24 hours:
-- MAGIC <pre><code class="language-sql">-- Use as a dashboard vizualisation with status indicators
-- MAGIC
-- MAGIC WITH job_summary AS (
-- MAGIC     SELECT 
-- MAGIC         j.name AS job_name,
-- MAGIC         COUNT(*) AS total_runs,
-- MAGIC         SUM(CASE WHEN r.result_state = 'SUCCESS' THEN 1 ELSE 0 END) AS successful,
-- MAGIC         SUM(CASE WHEN r.result_state = 'FAILED' THEN 1 ELSE 0 END) AS failed,
-- MAGIC         AVG(r.run_duration_seconds) AS avg_duration_sec
-- MAGIC     FROM system.lakeflow.job_run_timeline r
-- MAGIC     JOIN system.lakeflow.jobs j ON r.job_id = j.job_id
-- MAGIC     WHERE r.period_start_time >= current_timestamp() - INTERVAL 24 HOURS
-- MAGIC     GROUP BY j.name
-- MAGIC )
-- MAGIC
-- MAGIC SELECT 
-- MAGIC     job_name,
-- MAGIC     total_runs,
-- MAGIC     successful,
-- MAGIC     failed,
-- MAGIC     ROUND(100.0 * successful / total_runs, 1) AS success_rate_pct,
-- MAGIC     ROUND(avg_duration_sec / 60, 1) AS avg_duration_min,
-- MAGIC     CASE 
-- MAGIC         WHEN failed > 0 THEN 'DEGRADED'
-- MAGIC         WHEN 100.0 * successful / total_runs < 95 THEN 'WARNING'
-- MAGIC         ELSE 'HEALTHY'
-- MAGIC     END AS status
-- MAGIC FROM job_summary
-- MAGIC ORDER BY 
-- MAGIC     CASE WHEN failed > 0 THEN 0 ELSE 1 END,
-- MAGIC     success_rate_pct ASC;
-- MAGIC </code></pre>
-- MAGIC
-- MAGIC <link href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/themes/prism.min.css" rel="stylesheet" />
-- MAGIC <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/prism.min.js"></script>
-- MAGIC <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-sql.min.js"></script>

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC <div style="border-left: 4px solid #4caf50; background: #e8f5e9; padding: 16px 20px; border-radius: 8px; margin: 16px 0;">
-- MAGIC     <div style="display: flex; align-items: flex-start; gap: 12px;">
-- MAGIC         <span style="font-size: 24px;">✅</span>
-- MAGIC         <div>
-- MAGIC             <strong style="color: #2e7d32; font-size: 1.1em;">Observability Handoff Checklist</strong>
-- MAGIC             <ul style="margin: 8px 0 0 0; color: #333; padding-left: 20px;">
-- MAGIC                 <li>System tables accessible to operations team</li>
-- MAGIC                 <li>Notification destinations configured (Slack, Teams, PagerDuty, email)</li>
-- MAGIC                 <li>SQL Alerts created for job failures, SLA breaches, and cost anomalies</li>
-- MAGIC                 <li>Enterprise monitoring integration documented (or deployed)</li>
-- MAGIC                 <li>Lakehouse Monitors configured on critical tables</li>
-- MAGIC                 <li>Operational dashboards published with appropriate access</li>
-- MAGIC                 <li>Runbook documentation linked from alert descriptions</li>
-- MAGIC             </ul>
-- MAGIC         </div>
-- MAGIC     </div>
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Summary
-- MAGIC
-- MAGIC This lesson covered establishing enterprise-grade observability for ongoing platform operations after migration.
-- MAGIC
-- MAGIC **Key Takeaways:**
-- MAGIC
-- MAGIC - **System Tables** - The foundation for all Databricks observability; query directly or export to external platforms
-- MAGIC - **Enterprise Integration** - Push system table data to Splunk, Datadog, CloudWatch, or Azure Monitor via scheduled jobs
-- MAGIC - **SQL Alerts** - Proactive monitoring with multi-channel notification destinations
-- MAGIC - **Data Profiling** - Automated data quality
-- MAGIC - **Dashboards** - AI/BI Dashboards powered by system tables for operational visibility
-- MAGIC
-- MAGIC **References:**
-- MAGIC
-- MAGIC - [System Tables Overview](https://docs.databricks.com/en/admin/system-tables/index.html)
-- MAGIC - [SQL Alerts](https://docs.databricks.com/en/sql/user/alerts/index.html)
-- MAGIC - [Notification Destinations](https://docs.databricks.com/aws/en/admin/workspace-settings/notification-destinations)
-- MAGIC - [Data Profiling](https://docs.databricks.com/en/lakehouse-monitoring/index.html)
-- MAGIC - [Audit Logs](https://docs.databricks.com/en/admin/account-settings/audit-logs.html)

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC &copy; <span id="dbx-year"></span> Databricks, Inc. All rights reserved. Apache, Apache Spark, Spark, the Spark Logo, Apache Iceberg, Iceberg, and the Apache Iceberg logo are trademarks of the <a href="https://www.apache.org/" target="_blank">Apache Software Foundation</a>.<br/><br/><a href="https://databricks.com/privacy-policy" target="_blank">Privacy Policy</a> | <a href="https://databricks.com/terms-of-use" target="_blank">Terms of Use</a> | <a href="https://help.databricks.com/" target="_blank">Support</a>
-- MAGIC <script>
-- MAGIC   document.getElementById("dbx-year").textContent = new Date().getFullYear();
-- MAGIC </script>