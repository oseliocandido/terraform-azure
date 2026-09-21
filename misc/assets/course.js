/* ==========================================================================
   Terraform on Azure — course runtime
   Builds the sidebar, TOC, pager, progress tracking and diagram rendering
   from a single lesson manifest so every page stays in sync.
   ========================================================================== */
(function () {
  "use strict";

  /* ---------------------------------------------------------------- data */

  var LESSONS = [
    {
      id: "01", file: "01-infrastructure-as-code.html",
      title: "Infrastructure as Code & Terraform's architecture",
      nav: "IaC & Terraform architecture",
      phase: "beginner", part: "Part 1",
      desc: "Why Terraform exists, declarative vs imperative, how it compares to Bicep/Ansible/Pulumi, and what the CLI + provider + state actually are.",
      tags: ["Concepts", "Bicep vs Terraform", "Providers"], mins: 45
    },
    {
      id: "02", file: "02-terraform-workflow.html",
      title: "The Terraform workflow & CLI",
      nav: "Workflow & CLI",
      phase: "beginner", part: "Part 1",
      desc: "init → validate → plan → apply → destroy, and precisely what Terraform does during each step.",
      tags: ["CLI", "Lock file", "Plan"], mins: 50
    },
    {
      id: "03", file: "03-hcl.html",
      title: "HCL: types, expressions and functions",
      nav: "HCL language",
      phase: "beginner", part: "Part 2",
      desc: "Blocks, arguments, attributes, the full type system, conditionals, for-expressions, and how HCL differs from a normal programming language.",
      tags: ["HCL", "Types", "Expressions"], mins: 70
    },
    {
      id: "04", file: "04-azure-provider.html",
      title: "The AzureRM provider & authentication",
      nav: "AzureRM provider & auth",
      phase: "beginner", part: "Part 3",
      desc: "Provider configuration, version constraints, subscriptions and tenants, and the four ways Terraform authenticates to Azure — none of which involve hardcoded credentials.",
      tags: ["azurerm 5.x", "Entra ID", "OIDC"], mins: 60
    },
    {
      id: "05", file: "05-first-infrastructure.html",
      title: "Your first Azure infrastructure",
      nav: "First infrastructure",
      phase: "beginner", part: "Part 4",
      desc: "Resource group → storage account → container, resource IDs, regions, naming rules, and implicit vs explicit dependencies.",
      tags: ["Resource groups", "Dependencies", "Resource IDs"], mins: 55
    },
    {
      id: "06", file: "06-azure-storage.html",
      title: "Azure Storage & ADLS Gen2 for data lakes",
      nav: "Storage & ADLS Gen2",
      phase: "beginner", part: "Part 5",
      desc: "Hierarchical namespace, medallion containers, access tiers, lifecycle policies, encryption and network rules — the storage layer every data platform sits on.",
      tags: ["ADLS Gen2", "Medallion", "Lifecycle"], mins: 75
    },
    {
      id: "07", file: "07-variables.html",
      title: "Variables, locals, outputs & environments",
      nav: "Variables & environments",
      phase: "beginner", part: "Part 6",
      desc: "Input variables and their type system, validation, sensitivity, tfvars precedence, locals, outputs, and running dev/test/prod from one codebase.",
      tags: ["Variables", "tfvars", "Validation"], mins: 65
    },
    {
      id: "08", file: "08-identity-rbac.html",
      title: "Identity, Entra ID & Azure RBAC",
      nav: "Identity & RBAC",
      phase: "intermediate", part: "Part 7",
      desc: "Authentication vs authorization, users vs service principals vs managed identities, role definitions, scope inheritance and least privilege in Terraform.",
      tags: ["RBAC", "Managed identity", "Least privilege"], mins: 70
    },
    {
      id: "09", file: "09-key-vault.html",
      title: "Key Vault & the secrets-in-state problem",
      nav: "Key Vault & secrets",
      phase: "intermediate", part: "Part 8",
      desc: "Vault access models, secrets/keys/certificates, and the uncomfortable truth that `sensitive = true` does not encrypt anything in state.",
      tags: ["Key Vault", "Secrets", "State risk"], mins: 60
    },
    {
      id: "10", file: "10-state.html",
      title: "Terraform state & remote backends",
      nav: "State & backends",
      phase: "intermediate", part: "Part 9",
      desc: "The single most important concept in Terraform: what state is, why it exists, drift, locking, and the Azure Storage backend done properly.",
      tags: ["State", "Backend", "Locking"], mins: 80
    },
    {
      id: "11", file: "11-networking.html",
      title: "VNets, NSGs, private endpoints & private DNS",
      nav: "Networking & private endpoints",
      phase: "intermediate", part: "Part 10",
      desc: "Building a data-platform network: subnets, delegation, service endpoints vs private endpoints, and the private DNS wiring everyone gets wrong once.",
      tags: ["VNet", "Private Endpoint", "Private DNS"], mins: 80
    },
    {
      id: "12", file: "12-databricks.html",
      title: "Azure Databricks",
      nav: "Azure Databricks",
      phase: "intermediate", part: "Part 11",
      desc: "Workspace provisioning with VNet injection, the control-plane/data-plane split, Unity Catalog access connectors, and where AzureRM ends and the Databricks provider begins.",
      tags: ["Databricks", "VNet injection", "Unity Catalog"], mins: 90
    },
    {
      id: "13", file: "13-functions.html",
      title: "Azure Functions",
      nav: "Azure Functions",
      phase: "intermediate", part: "Part 12",
      desc: "Function apps, hosting plans, the mandatory storage account, identity-based storage connections, and app settings vs Key Vault references.",
      tags: ["Functions", "Service Plan", "App settings"], mins: 65
    },
    {
      id: "14", file: "14-modules.html",
      title: "Modules",
      nav: "Modules",
      phase: "intermediate", part: "Part 13",
      desc: "Root vs child modules, inputs and outputs as an API, composition, versioning, sources, and refactoring duplicated config into something reusable.",
      tags: ["Modules", "Composition", "Versioning"], mins: 80
    },
    {
      id: "15", file: "15-dynamic-infrastructure.html",
      title: "for_each, count, dynamic, lifecycle & dependencies",
      nav: "Dynamic infra & lifecycle",
      phase: "intermediate", part: "Parts 14–15",
      desc: "Meta-arguments that turn static config into dynamic infrastructure — plus the lifecycle rules that decide whether Terraform updates or destroys.",
      tags: ["for_each", "dynamic", "lifecycle"], mins: 80
    },
    {
      id: "16", file: "16-plan-and-import.html",
      title: "Reading plans, state surgery, import & brownfield",
      nav: "Plans, import & brownfield",
      phase: "intermediate", part: "Parts 16–17",
      desc: "Reading plan output line by line, the state subcommands, moved/removed/import blocks, and adopting Azure resources that already exist.",
      tags: ["Plan output", "import", "Drift"], mins: 85
    },
    {
      id: "17", file: "17-production.html",
      title: "Production Terraform",
      nav: "Production practices",
      phase: "production", part: "Part 18",
      desc: "Repository structure and its trade-offs, state isolation, blast radius, naming conventions, version pinning and provider upgrades.",
      tags: ["Repo structure", "Blast radius", "Pinning"], mins: 75
    },
    {
      id: "18", file: "18-cicd.html",
      title: "CI/CD for Terraform",
      nav: "CI/CD pipelines",
      phase: "production", part: "Part 19",
      desc: "GitHub Actions and Azure DevOps pipelines using OIDC workload identity federation — no stored secrets, saved plan artifacts and approval gates.",
      tags: ["OIDC", "Plan artifacts", "Approvals"], mins: 80
    },
    {
      id: "19", file: "19-testing.html",
      title: "Testing, scanning & policy as code",
      nav: "Testing & quality",
      phase: "production", part: "Part 20",
      desc: "fmt, validate, the native `terraform test` framework, static analysis, security scanning, policy as code and pre-commit hooks — and what each one cannot catch.",
      tags: ["terraform test", "tflint", "OPA"], mins: 70
    },
    {
      id: "20", file: "20-final-project.html",
      title: "Final project: an Azure data platform",
      nav: "Final project",
      phase: "capstone", part: "Part 21",
      desc: "Build the whole thing: networking, ADLS Gen2, Key Vault, managed identities, RBAC, Databricks, Functions, modules, remote state and a pipeline.",
      tags: ["Capstone", "End to end"], mins: 240
    }
  ];

  var PHASES = [
    { id: "beginner",     label: "Foundations",  note: "IaC concepts through your first real Azure resources" },
    { id: "intermediate", label: "Intermediate", note: "State, identity, networking and the data services" },
    { id: "production",   label: "Production",   note: "How this is actually run by a team" },
    { id: "capstone",     label: "Capstone",     note: "Put every part of the course together" }
  ];

  var PHASE_LABEL = {
    beginner: "Beginner", intermediate: "Intermediate",
    production: "Production", capstone: "Capstone"
  };

  var STORE_KEY   = "tfaz.progress.v1";
  var THEME_KEY   = "tfaz.theme.v1";
  var SIDEBAR_KEY = "tfaz.sidebar.v1";
  var CHECKPOINT_KEY = "tfaz.checkpoints.v1";

  /* ------------------------------------------------------------- storage */

  function readDone() {
    try {
      var raw = localStorage.getItem(STORE_KEY);
      var arr = raw ? JSON.parse(raw) : [];
      return Array.isArray(arr) ? arr : [];
    } catch (e) { return []; }
  }

  function writeDone(list) {
    try { localStorage.setItem(STORE_KEY, JSON.stringify(list)); } catch (e) { /* private mode */ }
  }

  function isDone(id) { return readDone().indexOf(id) !== -1; }

  function toggleDone(id) {
    var list = readDone();
    var i = list.indexOf(id);
    if (i === -1) { list.push(id); } else { list.splice(i, 1); }
    writeDone(list);
    return list.indexOf(id) !== -1;
  }

  /* --------------------------------------------------------------- theme */

  function currentTheme() {
    try { return localStorage.getItem(THEME_KEY) || "auto"; } catch (e) { return "auto"; }
  }

  function applyTheme(mode) {
    var root = document.documentElement;
    if (mode === "auto") { root.removeAttribute("data-theme"); }
    else { root.setAttribute("data-theme", mode); }
    try { localStorage.setItem(THEME_KEY, mode); } catch (e) {}
    var btn = document.querySelector(".theme-toggle");
    if (btn) {
      btn.textContent = mode === "dark" ? "☀" : mode === "light" ? "◐" : "◑";
      btn.title = "Theme: " + mode + " (click to change)";
    }
  }

  function effectiveDark() {
    var t = document.documentElement.getAttribute("data-theme");
    if (t === "dark") return true;
    if (t === "light") return false;
    return window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
  }

  /* ----------------------------------------------------- sidebar collapse */

  function sidebarCollapsed() {
    return document.documentElement.classList.contains("sidebar-collapsed");
  }

  function setSidebarCollapsed(collapsed) {
    document.documentElement.classList.toggle("sidebar-collapsed", collapsed);
    try {
      localStorage.setItem(SIDEBAR_KEY, collapsed ? "collapsed" : "expanded");
    } catch (e) { /* private mode */ }
    var btn = document.getElementById("sidebarCollapse");
    if (btn) btn.setAttribute("aria-expanded", String(!collapsed));
  }

  /* -------------------------------------------------------------- chrome */

  function buildChrome() {
    var body = document.body;
    var currentId = body.getAttribute("data-lesson") || null;   // null on index
    var done = readDone();

    /* topbar (mobile) */
    var topbar = document.createElement("div");
    topbar.className = "topbar";
    topbar.innerHTML =
      '<button class="icon-btn" id="navToggle" aria-label="Open navigation">☰</button>' +
      '<strong style="font-size:14px">' +
        (currentId ? "Lesson " + currentId : "Terraform on Azure") +
      "</strong>";

    /* sidebar */
    var side = document.createElement("aside");
    side.className = "sidebar";
    side.id = "courseSidebar";

    var html =
      '<div class="brand">' +
        '<a href="index.html">' +
          '<span class="brand-mark">TF</span>' +
          '<span class="brand-text"><strong>Terraform on Azure</strong>' +
          "<span>Data engineering track</span></span>" +
        "</a>" +
        '<button class="icon-btn sidebar-toggle" id="sidebarCollapse" type="button" ' +
          'aria-label="Collapse sidebar" aria-controls="courseSidebar" aria-expanded="true" ' +
          'title="Collapse sidebar  ( [ )">«</button>' +
      "</div>";

    PHASES.forEach(function (phase) {
      var items = LESSONS.filter(function (l) { return l.phase === phase.id; });
      if (!items.length) return;
      html += '<div class="nav-group-label">' + phase.label + "</div><ul class=\"nav-list\">";
      items.forEach(function (l) {
        var cls = [];
        if (l.id === currentId) cls.push("is-current");
        if (done.indexOf(l.id) !== -1) cls.push("is-done");
        html +=
          '<li><a class="' + cls.join(" ") + '" href="' + l.file + '">' +
            '<span class="nav-num">' + l.id + "</span>" +
            "<span>" + l.nav + "</span>" +
          "</a></li>";
      });
      html += "</ul>";
    });

    html +=
      '<div class="nav-group-label">Reference</div><ul class="nav-list">' +
        '<li><a href="index.html"><span class="nav-num">⌂</span><span>Course dashboard</span></a></li>' +
      "</ul>";

    side.innerHTML = html;

    var scrim = document.createElement("div");
    scrim.className = "nav-scrim";

    /* toc column */
    var toc = document.createElement("nav");
    toc.className = "toc";
    toc.innerHTML = '<div class="toc-title">On this page</div><ul></ul>';

    /* assemble: wrap existing <main> */
    var main = document.querySelector("main.content");
    var layout = document.createElement("div");
    layout.className = "layout";
    body.insertBefore(topbar, body.firstChild);
    body.insertBefore(layout, main);
    layout.appendChild(side);
    layout.appendChild(main);
    layout.appendChild(toc);
    body.appendChild(scrim);

    /* theme button */
    var tbtn = document.createElement("button");
    tbtn.className = "icon-btn theme-toggle";
    tbtn.setAttribute("aria-label", "Toggle colour theme");
    body.appendChild(tbtn);
    applyTheme(currentTheme());
    tbtn.addEventListener("click", function () {
      var order = ["auto", "light", "dark"];
      var next = order[(order.indexOf(currentTheme()) + 1) % order.length];
      applyTheme(next);
      retheme();
    });

    /* desktop sidebar collapse — the edge button shown while collapsed */
    var reopen = document.createElement("button");
    reopen.className = "icon-btn sidebar-reopen";
    reopen.id = "sidebarReopen";
    reopen.type = "button";
    reopen.textContent = "»";
    reopen.title = "Show sidebar  ( [ )";
    reopen.setAttribute("aria-label", "Show sidebar");
    reopen.setAttribute("aria-controls", "courseSidebar");
    body.appendChild(reopen);

    document.getElementById("sidebarCollapse")
      .addEventListener("click", function () { setSidebarCollapsed(true); });
    reopen.addEventListener("click", function () { setSidebarCollapsed(false); });

    /* "[" toggles it from the keyboard */
    document.addEventListener("keydown", function (ev) {
      if (ev.key !== "[" || ev.metaKey || ev.ctrlKey || ev.altKey) return;
      var t = ev.target;
      if (t && (t.tagName === "INPUT" || t.tagName === "TEXTAREA" || t.isContentEditable)) return;
      ev.preventDefault();
      setSidebarCollapsed(!sidebarCollapsed());
    });

    /* keep aria-expanded honest on load (the inline head script sets the class) */
    setSidebarCollapsed(sidebarCollapsed());

    /* mobile nav */
    document.getElementById("navToggle").addEventListener("click", function () {
      body.classList.toggle("nav-open");
    });
    scrim.addEventListener("click", function () { body.classList.remove("nav-open"); });

    return { toc: toc, currentId: currentId };
  }

  /* --------------------------------------------------------- code blocks */

  function decorateCode() {
    document.querySelectorAll(".code").forEach(function (box) {
      var head = box.querySelector(".code-head");
      if (!head) return;
      if (head.querySelector(".copy-btn")) return;
      var btn = document.createElement("button");
      btn.className = "copy-btn";
      btn.type = "button";
      btn.textContent = "Copy";
      btn.addEventListener("click", function () {
        var code = box.querySelector("pre");
        if (!code) return;
        var text = code.innerText;
        var done = function () {
          btn.textContent = "Copied";
          btn.classList.add("is-copied");
          setTimeout(function () {
            btn.textContent = "Copy";
            btn.classList.remove("is-copied");
          }, 1400);
        };
        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(text).then(done, function () {});
        } else {
          var ta = document.createElement("textarea");
          ta.value = text;
          document.body.appendChild(ta);
          ta.select();
          try { document.execCommand("copy"); done(); } catch (e) {}
          document.body.removeChild(ta);
        }
      });
      head.appendChild(btn);
    });
  }

  /* ----------------------------------------------------------------- toc */

  function buildToc(tocEl) {
    var main = document.querySelector("main.content");
    if (!main || !tocEl) return;
    var heads = main.querySelectorAll("h2, h3");
    var ul = tocEl.querySelector("ul");
    var n = 0;

    heads.forEach(function (h) {
      if (h.closest(".objectives, .card, .exercise, details, .callout")) return;
      if (!h.id) {
        h.id = h.textContent.trim().toLowerCase()
          .replace(/[^\w\s-]/g, "").replace(/\s+/g, "-").slice(0, 60) || "s" + n;
      }
      // permalink
      if (!h.querySelector(".anchor")) {
        var a = document.createElement("a");
        a.className = "anchor";
        a.href = "#" + h.id;
        a.textContent = "#";
        a.setAttribute("aria-hidden", "true");
        h.appendChild(a);
      }
      var li = document.createElement("li");
      li.className = "toc-" + h.tagName.toLowerCase();
      var link = document.createElement("a");
      link.href = "#" + h.id;
      link.textContent = h.firstChild ? h.textContent.replace(/#$/, "").trim() : "";
      li.appendChild(link);
      ul.appendChild(li);
      n++;
    });

    if (!n) { tocEl.style.display = "none"; return; }

    /* scroll spy */
    var links = Array.prototype.slice.call(ul.querySelectorAll("a"));
    var targets = links.map(function (l) { return document.getElementById(l.getAttribute("href").slice(1)); });

    var spy = function () {
      var best = 0;
      for (var i = 0; i < targets.length; i++) {
        if (targets[i] && targets[i].getBoundingClientRect().top <= 120) best = i;
      }
      links.forEach(function (l, i) { l.classList.toggle("is-active", i === best); });
    };
    var ticking = false;
    window.addEventListener("scroll", function () {
      if (ticking) return;
      ticking = true;
      window.requestAnimationFrame(function () { spy(); ticking = false; });
    }, { passive: true });
    spy();
  }

  /* --------------------------------------------------------------- pager */

  function buildPager(currentId) {
    if (!currentId) return;
    var main = document.querySelector("main.content");
    var i = LESSONS.findIndex(function (l) { return l.id === currentId; });
    if (i === -1) return;
    var prev = LESSONS[i - 1], next = LESSONS[i + 1];

    /* mark-complete bar */
    var bar = document.createElement("div");
    bar.className = "complete-bar";
    var doneNow = isDone(currentId);
    bar.innerHTML =
      '<div><strong style="font-size:14.5px">Finished this lesson?</strong>' +
      '<div style="font-size:13px;color:var(--text-muted)">Progress is stored in this browser only.</div></div>';
    var btn = document.createElement("button");
    btn.className = "btn" + (doneNow ? " is-done" : "");
    btn.type = "button";
    btn.textContent = doneNow ? "✓ Completed" : "Mark as complete";
    btn.addEventListener("click", function () {
      var now = toggleDone(currentId);
      btn.textContent = now ? "✓ Completed" : "Mark as complete";
      btn.classList.toggle("is-done", now);
      var navLink = document.querySelector('.nav-list a[href="' + LESSONS[i].file + '"]');
      if (navLink) navLink.classList.toggle("is-done", now);
    });
    bar.appendChild(btn);
    main.appendChild(bar);

    var pager = document.createElement("nav");
    pager.className = "pager";
    pager.innerHTML =
      (prev
        ? '<a class="prev" href="' + prev.file + '"><div class="dir">← Previous</div>' +
          '<div class="ttl">' + prev.nav + "</div></a>"
        : '<span class="spacer"></span>') +
      (next
        ? '<a class="next" href="' + next.file + '"><div class="dir">Next →</div>' +
          '<div class="ttl">' + next.nav + "</div></a>"
        : '<a class="next" href="index.html"><div class="dir">Back to →</div>' +
          '<div class="ttl">Course dashboard</div></a>');
    main.appendChild(pager);
  }

  /* ------------------------------------------------------------ diagrams */

  function mermaidTheme() {
    var dark = effectiveDark();
    return {
      startOnLoad: false,
      securityLevel: "loose",
      theme: "base",
      fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', Inter, sans-serif",
      themeVariables: dark
        ? {
            background: "#1a1d23", primaryColor: "#23204a", primaryTextColor: "#e4e7ec",
            primaryBorderColor: "#6f63e0", lineColor: "#7b8494", secondaryColor: "#16293a",
            tertiaryColor: "#22252c", clusterBkg: "#14161b", clusterBorder: "#2a2e37",
            nodeTextColor: "#e4e7ec", edgeLabelBackground: "#1a1d23", fontSize: "14px"
          }
        : {
            background: "#ffffff", primaryColor: "#efedfd", primaryTextColor: "#1c2024",
            primaryBorderColor: "#5c4ee5", lineColor: "#8b95a3", secondaryColor: "#e6f2fb",
            tertiaryColor: "#f2f4f7", clusterBkg: "#f7f8fa", clusterBorder: "#e2e6ec",
            nodeTextColor: "#1c2024", edgeLabelBackground: "#ffffff", fontSize: "14px"
          }
    };
  }

  function renderDiagrams() {
    if (typeof window.mermaid === "undefined") return;
    var nodes = document.querySelectorAll(".mermaid");
    if (!nodes.length) return;
    nodes.forEach(function (n) {
      if (!n.getAttribute("data-src")) n.setAttribute("data-src", n.textContent);
    });
    try {
      window.mermaid.initialize(mermaidTheme());
      window.mermaid.run({ nodes: nodes });
    } catch (e) { /* leave the source text visible */ }
  }

  function retheme() {
    if (typeof window.mermaid === "undefined") return;
    document.querySelectorAll(".mermaid").forEach(function (n) {
      var src = n.getAttribute("data-src");
      if (src) { n.removeAttribute("data-processed"); n.innerHTML = src; }
    });
    renderDiagrams();
  }

  /* --------------------------------------------------------------- index */

  function buildIndex() {
    var mount = document.getElementById("courseIndex");
    if (!mount) return;
    var done = readDone();

    var totalMins = LESSONS.reduce(function (a, l) { return a + l.mins; }, 0);

    /* stats */
    var stats = document.getElementById("courseStats");
    if (stats) {
      stats.innerHTML =
        '<div class="stat"><div class="n">' + LESSONS.length + '</div><div class="l">Lessons</div></div>' +
        '<div class="stat"><div class="n">' + Math.round(totalMins / 60) + 'h</div><div class="l">Estimated study time</div></div>' +
        '<div class="stat"><div class="n">4</div><div class="l">Difficulty phases</div></div>' +
        '<div class="stat"><div class="n">1</div><div class="l">Capstone project</div></div>';
    }

    /* progress */
    function paintProgress() {
      var d = readDone().filter(function (id) {
        return LESSONS.some(function (l) { return l.id === id; });
      });
      var pct = Math.round((d.length / LESSONS.length) * 100);
      var fill = document.querySelector(".progress-fill");
      var label = document.getElementById("progressLabel");
      if (fill) fill.style.width = pct + "%";
      if (label) label.textContent = d.length + " of " + LESSONS.length + " complete · " + pct + "%";
    }

    var html = "";
    PHASES.forEach(function (phase) {
      var items = LESSONS.filter(function (l) { return l.phase === phase.id; });
      if (!items.length) return;
      html +=
        '<div class="phase-head">' +
          '<span class="pill pill-' + phase.id + '">' + PHASE_LABEL[phase.id] + "</span>" +
          "<h2>" + phase.label + "</h2>" +
          '<span class="rule"></span>' +
          '<span style="font-size:12.5px;color:var(--text-faint);text-align:right;max-width:320px">' + phase.note + "</span>" +
        "</div>" +
        '<div class="lesson-grid">';
      items.forEach(function (l) {
        var d = done.indexOf(l.id) !== -1;
        html +=
          '<a class="lesson-card' + (d ? " is-done" : "") + '" href="' + l.file + '" data-id="' + l.id + '">' +
            '<div class="idx">' + l.id + "</div>" +
            "<div>" +
              '<div class="ttl">' + l.title + "</div>" +
              '<div class="desc">' + l.desc + "</div>" +
              '<div class="tags">' +
                l.tags.map(function (t) { return '<span class="tag">' + t + "</span>"; }).join("") +
                '<span class="tag">' + l.part + "</span>" +
              "</div>" +
            "</div>" +
            '<div class="side">' +
              '<div class="check">✓</div>' +
              '<div style="font-size:11.5px;color:var(--text-faint);white-space:nowrap">~' + l.mins + " min</div>" +
            "</div>" +
          "</a>";
      });
      html += "</div>";
    });

    mount.innerHTML = html;
    paintProgress();

    /* click the tick to toggle completion without navigating */
    mount.querySelectorAll(".lesson-card .check").forEach(function (chk) {
      chk.addEventListener("click", function (ev) {
        ev.preventDefault();
        ev.stopPropagation();
        var card = chk.closest(".lesson-card");
        var now = toggleDone(card.getAttribute("data-id"));
        card.classList.toggle("is-done", now);
        var navLink = document.querySelector('.nav-list a[href="' + card.getAttribute("href") + '"]');
        if (navLink) navLink.classList.toggle("is-done", now);
        paintProgress();
      });
      chk.title = "Toggle complete";
      chk.style.cursor = "pointer";
    });

    var reset = document.getElementById("resetProgress");
    if (reset) {
      reset.addEventListener("click", function () {
        writeDone([]);
        mount.querySelectorAll(".lesson-card").forEach(function (c) { c.classList.remove("is-done"); });
        document.querySelectorAll(".nav-list a").forEach(function (a) { a.classList.remove("is-done"); });
        paintProgress();
      });
    }
  }

  /* ---------------------------------------- capstone checkpoints (L20) */

  function readPassedCheckpoints() {
    try {
      var raw = localStorage.getItem(CHECKPOINT_KEY);
      var arr = raw ? JSON.parse(raw) : [];
      return Array.isArray(arr) ? arr : [];
    } catch (e) { return []; }
  }

  function writePassedCheckpoints(list) {
    try { localStorage.setItem(CHECKPOINT_KEY, JSON.stringify(list)); } catch (e) {}
  }

  function isCheckpointPassed(id) {
    return readPassedCheckpoints().indexOf(id) !== -1;
  }

  function toggleCheckpoint(id) {
    var list = readPassedCheckpoints();
    var i = list.indexOf(id);
    if (i === -1) { list.push(id); } else { list.splice(i, 1); }
    writePassedCheckpoints(list);
    return list.indexOf(id) !== -1;
  }

  function paintCheckpointSummary(nodes) {
    var bar = document.getElementById("checkpointSummary");
    if (!bar) return;
    var passed = readPassedCheckpoints().filter(function (id) {
      return nodes.some(function (n) { return n.getAttribute("data-cp") === id; });
    });
    var pct = nodes.length ? Math.round((passed.length / nodes.length) * 100) : 0;
    var fill = bar.querySelector(".progress-fill");
    var label = bar.querySelector(".checkpoint-summary-label");
    if (fill) fill.style.width = pct + "%";
    if (label) label.textContent = passed.length + " of " + nodes.length + " checkpoints passed · " + pct + "%";
  }

  function buildCheckpoints() {
    var nodes = Array.prototype.slice.call(document.querySelectorAll(".checkpoint[data-cp]"));
    if (!nodes.length) return;

    /* summary bar, inserted once right after the lesson objectives box */
    if (!document.getElementById("checkpointSummary")) {
      var host = document.querySelector(".objectives") || document.querySelector(".lesson-head");
      if (host) {
        var bar = document.createElement("div");
        bar.className = "checkpoint-summary";
        bar.id = "checkpointSummary";
        bar.innerHTML =
          '<div class="progress-head"><strong>Checkpoint progress</strong>' +
          '<span class="checkpoint-summary-label"></span></div>' +
          '<div class="progress-track"><div class="progress-fill"></div></div>';
        host.parentNode.insertBefore(bar, host.nextSibling);
      }
    }

    nodes.forEach(function (n) {
      var id = n.getAttribute("data-cp");
      n.classList.toggle("is-passed", isCheckpointPassed(id));
      var btn = n.querySelector(".checkpoint-toggle[data-cp-btn]");
      if (!btn) return;
      btn.textContent = isCheckpointPassed(id) ? "✓ Passed" : "Mark as passed";
      btn.addEventListener("click", function () {
        var now = toggleCheckpoint(id);
        n.classList.toggle("is-passed", now);
        btn.textContent = now ? "✓ Passed" : "Mark as passed";
        paintCheckpointSummary(nodes);
      });
    });

    paintCheckpointSummary(nodes);
  }

  /* ----------------------------------------------------------------- go */

  function init() {
    var chrome = buildChrome();
    decorateCode();
    buildToc(chrome.toc);
    buildPager(chrome.currentId);
    buildIndex();
    buildCheckpoints();
    renderDiagrams();

    if (window.matchMedia) {
      var mq = window.matchMedia("(prefers-color-scheme: dark)");
      var handler = function () { if (currentTheme() === "auto") retheme(); };
      if (mq.addEventListener) mq.addEventListener("change", handler);
      else if (mq.addListener) mq.addListener(handler);
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
