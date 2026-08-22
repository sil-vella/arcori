(() => {
  const sessionMetaEl = document.getElementById("session-meta");
  const accordionNavEl = document.getElementById("accordion-nav");
  const accordionContentEl = document.getElementById("accordion-content");
  const activeScriptEl = document.getElementById("active-script");
  const stopBtn = document.getElementById("stop-btn");
  const runBtn = document.getElementById("run-btn");
  const terminalToolbarEl = document.getElementById("terminal-toolbar");
  const sessionIdBtn = document.getElementById("session-id-btn");
  const copySessionIdBtn = document.getElementById("copy-session-id-btn");
  const mirrorGlobalLogLabel = document.getElementById("mirror-global-log-label");
  const mirrorGlobalLogCheck = document.getElementById("mirror-global-log-check");
  const terminalTabsEl = document.getElementById("terminal-tabs");
  const terminalStackEl = document.getElementById("terminal-stack");
  const terminalPlaceholderEl = document.getElementById("terminal-placeholder");
  const mainTabsEl = document.getElementById("main-tabs");
  const taskManagerFrame = document.getElementById("task-manager-frame");
  const taskManagerMissingEl = document.getElementById("task-manager-missing");
  const taskManagerStatusEl = document.getElementById("task-manager-status");

  const MIRROR_LOG_STORAGE_KEY = "wfrun.mirrorGlobalLog";

  /** @type {Map<string, {
   *   sessionKey: string,
   *   scriptId: string,
   *   logFile: string | null,
   *   runnable: boolean,
   *   term: Terminal,
   *   fitAddon: FitAddon,
   *   hostEl: HTMLElement,
   *   tabEl: HTMLButtonElement | null,
   *   ws: WebSocket | null,
   *   running: boolean,
   *   onDataDisposable: { dispose: () => void } | null,
   * }>} */
  const sessions = new Map();

  let activeSessionKey = null;
  let activeGroup = null;
  let groupedScripts = [];
  let activeView = "scripts";
  let taskManagerUrl = "";

  function isAbsoluteHttpUrl(value) {
    return /^https?:\/\/[^/\s]+/i.test(value);
  }

  function setTaskManagerStatus(text) {
    if (!taskManagerStatusEl) {
      return;
    }
    if (!text) {
      taskManagerStatusEl.hidden = true;
      taskManagerStatusEl.textContent = "";
      return;
    }
    taskManagerStatusEl.hidden = false;
    taskManagerStatusEl.textContent = text;
  }

  function ensureEmbedLoaded(frame) {
    if (!frame) {
      return;
    }
    if (!taskManagerUrl || !isAbsoluteHttpUrl(taskManagerUrl)) {
      frame.removeAttribute("src");
      frame.hidden = true;
      if (taskManagerMissingEl) {
        taskManagerMissingEl.hidden = false;
      }
      setTaskManagerStatus("");
      frame.dataset.loaded = "";
      return;
    }
    if (frame.dataset.loaded === "1" && frame.getAttribute("src") === taskManagerUrl) {
      frame.hidden = false;
      if (taskManagerMissingEl) {
        taskManagerMissingEl.hidden = true;
      }
      setTaskManagerStatus(taskManagerUrl);
      return;
    }
    frame.hidden = false;
    if (taskManagerMissingEl) {
      taskManagerMissingEl.hidden = true;
    }
    // Never assign relative/empty src — browsers resolve "" to this dashboard origin.
    frame.src = taskManagerUrl;
    frame.dataset.loaded = "1";
    setTaskManagerStatus(taskManagerUrl);
  }

  function setActiveView(view) {
    activeView = view;

    mainTabsEl.querySelectorAll(".main-tab").forEach((tab) => {
      const isActive = tab.dataset.view === view;
      tab.classList.toggle("active", isActive);
      tab.setAttribute("aria-selected", isActive ? "true" : "false");
    });

    document.querySelectorAll(".view-panel").forEach((panel) => {
      const isActive = panel.dataset.view === view;
      panel.classList.toggle("active", isActive);
      panel.hidden = !isActive;
    });

    if (view === "task-manager") {
      ensureEmbedLoaded(taskManagerFrame);
    }

    if (window.DocsDash && typeof window.DocsDash.onView === "function") {
      window.DocsDash.onView(view);
    }

    if (window.RevenueDash && typeof window.RevenueDash.onView === "function") {
      window.RevenueDash.onView(view);
    }

    if (view === "scripts" && activeSessionKey) {
      const session = sessions.get(activeSessionKey);
      if (session) {
        requestAnimationFrame(() => {
          session.fitAddon.fit();
          if (session.ws && session.ws.readyState === WebSocket.OPEN) {
            session.ws.send(
              JSON.stringify({
                type: "resize",
                cols: session.term.cols,
                rows: session.term.rows,
              })
            );
          }
        });
      }
    }
  }

  function basename(scriptId) {
    return scriptId.split("/").pop();
  }

  function newSessionKey() {
    if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
      return crypto.randomUUID();
    }
    return `s-${Date.now()}-${Math.random().toString(16).slice(2)}`;
  }

  function getActiveSession() {
    return activeSessionKey ? sessions.get(activeSessionKey) : null;
  }

  function getActiveScriptId() {
    return getActiveSession()?.scriptId ?? null;
  }

  function sessionsForScript(scriptId) {
    return [...sessions.values()].filter((session) => session.scriptId === scriptId);
  }

  function tabLabel(session) {
    const name = basename(session.scriptId);
    const same = sessionsForScript(session.scriptId);
    if (same.length < 2) {
      return name;
    }
    return `${name} · ${same.indexOf(session) + 1}`;
  }

  function escapeHtml(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;");
  }

  function supportsMirrorGlobalLog(scriptId) {
    return (
      scriptId === "automation/backend/docker_up.sh" ||
      scriptId === "automation/backend/docker_up_build.sh"
    );
  }

  function readMirrorGlobalLogPref() {
    try {
      return localStorage.getItem(MIRROR_LOG_STORAGE_KEY) === "1";
    } catch (_err) {
      return false;
    }
  }

  function writeMirrorGlobalLogPref(on) {
    try {
      localStorage.setItem(MIRROR_LOG_STORAGE_KEY, on ? "1" : "0");
    } catch (_err) {
      /* ignore quota / private mode */
    }
  }

  function updateToolbar() {
    const session = getActiveSession();
    const hasSession = Boolean(session);
    terminalToolbarEl.hidden = !hasSession;
    stopBtn.disabled = !(session && session.running);
    runBtn.disabled = !(session && session.runnable);
    copySessionIdBtn.disabled = !(session && session.logFile);
    if (mirrorGlobalLogLabel && mirrorGlobalLogCheck) {
      const showMirror = Boolean(session && supportsMirrorGlobalLog(session.scriptId));
      mirrorGlobalLogLabel.hidden = !showMirror;
      if (showMirror) {
        mirrorGlobalLogCheck.checked = readMirrorGlobalLogPref();
      }
    }
    if (session) {
      const logLabel = session.logFile || "(no log yet — run script)";
      sessionIdBtn.textContent = logLabel;
      sessionIdBtn.title = session.logFile || "Run the script to create a log file";
      sessionIdBtn.disabled = !session.logFile;
      activeScriptEl.textContent = session.scriptId;
    } else {
      sessionIdBtn.textContent = "";
      sessionIdBtn.title = "";
      sessionIdBtn.disabled = true;
      activeScriptEl.textContent = "";
    }
  }

  function renderSession(session) {
    const brand = String(session.repo_brand || "").trim() || "dashboard";
    const brandTitle = `${brand} dashboard`;
    const brandEl = document.getElementById("dashboard-brand-title");
    if (brandEl) {
      brandEl.textContent = brandTitle;
    }
    document.title = brandTitle;

    if (!session.env_file) {
      sessionMetaEl.textContent = `${session.mode} · ${session.profile}`;
      return;
    }
    const envName = session.env_file_name || session.env_file.split("/").pop();
    sessionMetaEl.replaceChildren();

    const modeRow = document.createElement("div");
    modeRow.innerHTML = `<strong>mode</strong> ${escapeHtml(session.mode)}`;
    sessionMetaEl.appendChild(modeRow);

    const envRow = document.createElement("div");
    const envLabel = document.createElement("strong");
    envLabel.textContent = "env ";
    const envLink = document.createElement("a");
    envLink.className = "env-file-link";
    envLink.href = "#";
    envLink.textContent = envName;
    envLink.title = session.env_file;
    envLink.addEventListener("click", async (event) => {
      event.preventDefault();
      const res = await fetch("/api/open-env-file", { method: "POST" });
      if (!res.ok) {
        const active = getActiveSession();
        if (active) {
          active.term.writeln("\r\n\x1b[31mCould not open env file\x1b[0m");
        }
      }
    });
    envRow.appendChild(envLabel);
    envRow.appendChild(envLink);
    sessionMetaEl.appendChild(envRow);
  }

  function groupScripts(scripts) {
    const groups = new Map();
    for (const script of scripts) {
      const key = script.group || "other";
      if (!groups.has(key)) {
        groups.set(key, []);
      }
      groups.get(key).push(script);
    }
    return [...groups.entries()].sort(([a], [b]) => a.localeCompare(b));
  }

  function markSidebarActive(scriptId) {
    document.querySelectorAll(".script-link").forEach((el) => {
      const id = el.dataset.scriptId;
      const related = sessionsForScript(id);
      el.classList.toggle("active", id === scriptId);
      el.classList.toggle("has-terminal", related.length > 0);
      el.classList.toggle("running", related.some((session) => session.running));
    });
  }

  function renderTerminalTabs() {
    terminalTabsEl.replaceChildren();
    for (const session of sessions.values()) {
      const tab = document.createElement("button");
      tab.type = "button";
      tab.className = "terminal-tab";
      if (session.sessionKey === activeSessionKey) {
        tab.classList.add("active");
      }
      if (session.running) {
        tab.classList.add("running");
      }
      tab.dataset.sessionKey = session.sessionKey;
      tab.title = session.logFile
        ? `${session.scriptId}\n${session.logFile}`
        : session.scriptId;
      tab.innerHTML = `
        <span class="terminal-tab-label">${escapeHtml(tabLabel(session))}</span>
        <span class="terminal-tab-close" title="Close terminal" aria-label="Close">×</span>
      `;
      tab.addEventListener("click", (event) => {
        const close = event.target.closest(".terminal-tab-close");
        if (close) {
          event.stopPropagation();
          closeTerminalSession(session.sessionKey);
          return;
        }
        focusTerminal(session.sessionKey);
      });
      session.tabEl = tab;
      terminalTabsEl.appendChild(tab);
    }
  }

  function focusTerminal(sessionKey) {
    if (!sessions.has(sessionKey)) {
      return;
    }
    activeSessionKey = sessionKey;
    terminalPlaceholderEl.hidden = true;

    for (const session of sessions.values()) {
      session.hostEl.hidden = session.sessionKey !== sessionKey;
      if (session.tabEl) {
        session.tabEl.classList.toggle("active", session.sessionKey === sessionKey);
      }
    }

    const session = sessions.get(sessionKey);
    requestAnimationFrame(() => {
      session.fitAddon.fit();
      session.term.focus();
      if (session.ws && session.ws.readyState === WebSocket.OPEN) {
        session.ws.send(
          JSON.stringify({
            type: "resize",
            cols: session.term.cols,
            rows: session.term.rows,
          })
        );
      }
    });

    markSidebarActive(session.scriptId);
    updateToolbar();
  }

  function openTerminalPanel(scriptId, { runnable = true, forceNew = false } = {}) {
    let session = null;
    if (!forceNew) {
      const active = getActiveSession();
      if (active && active.scriptId === scriptId) {
        session = active;
      } else {
        const matches = sessionsForScript(scriptId);
        session = matches.length ? matches[matches.length - 1] : null;
      }
    }
    if (!session) {
      const sessionKey = newSessionKey();
      const hostEl = document.createElement("div");
      hostEl.className = "terminal-host";
      hostEl.dataset.sessionKey = sessionKey;
      hostEl.dataset.scriptId = scriptId;
      hostEl.hidden = true;
      terminalStackEl.appendChild(hostEl);
      terminalPlaceholderEl.hidden = true;

      const term = new Terminal({
        cursorBlink: true,
        fontFamily:
          "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace",
        fontSize: 13,
        theme: {
          background: "#0f1117",
          foreground: "#e6eaf2",
        },
      });
      const fitAddon = new FitAddon.FitAddon();
      term.loadAddon(fitAddon);
      term.open(hostEl);

      session = {
        sessionKey,
        scriptId,
        logFile: null,
        runnable,
        term,
        fitAddon,
        hostEl,
        tabEl: null,
        ws: null,
        running: false,
        onDataDisposable: null,
      };
      sessions.set(sessionKey, session);
      renderTerminalTabs();
      term.writeln(`\x1b[90mTerminal ready — press Run script to start\x1b[0m`);
    }
    focusTerminal(session.sessionKey);
    return session;
  }

  function stopSession(sessionKey, { writeStopped = false } = {}) {
    const session = sessions.get(sessionKey);
    if (!session) {
      return;
    }
    if (session.ws) {
      session.ws.close();
      session.ws = null;
    }
    if (session.onDataDisposable) {
      session.onDataDisposable.dispose();
      session.onDataDisposable = null;
    }
    session.running = false;
    if (writeStopped) {
      session.term.writeln("\r\n\x1b[33m[stopped by user]\x1b[0m");
    }
    if (session.tabEl) {
      session.tabEl.classList.remove("running");
    }
    markSidebarActive(getActiveScriptId());
    updateToolbar();
    renderTerminalTabs();
  }

  function closeTerminalSession(sessionKey) {
    const session = sessions.get(sessionKey);
    if (!session) {
      return;
    }
    stopSession(sessionKey);
    session.term.dispose();
    session.hostEl.remove();
    sessions.delete(sessionKey);
    renderTerminalTabs();

    if (activeSessionKey === sessionKey) {
      const remaining = [...sessions.keys()];
      if (remaining.length > 0) {
        focusTerminal(remaining[remaining.length - 1]);
      } else {
        activeSessionKey = null;
        terminalPlaceholderEl.hidden = false;
        markSidebarActive(null);
        updateToolbar();
      }
    } else {
      markSidebarActive(getActiveScriptId());
      updateToolbar();
    }
  }

  function wsUrl(scriptId, cols, rows) {
    const params = new URLSearchParams({
      script: scriptId,
      cols: String(cols),
      rows: String(rows),
    });
    if (supportsMirrorGlobalLog(scriptId)) {
      const wantMirror = Boolean(mirrorGlobalLogCheck && mirrorGlobalLogCheck.checked);
      params.set("mirror_global_log", wantMirror ? "1" : "0");
    }
    const proto = window.location.protocol === "https:" ? "wss:" : "ws:";
    return `${proto}//${window.location.host}/ws/run?${params.toString()}`;
  }

  function runActiveScript() {
    const current = getActiveSession();
    if (!current || !current.runnable) {
      return;
    }

    const session = current.running
      ? openTerminalPanel(current.scriptId, {
          runnable: current.runnable,
          forceNew: true,
        })
      : current;

    stopSession(session.sessionKey);
    session.term.reset();
    session.logFile = null;
    session.running = true;
    updateToolbar();
    renderTerminalTabs();
    markSidebarActive(session.scriptId);

    session.fitAddon.fit();
    const ws = new WebSocket(
      wsUrl(session.scriptId, session.term.cols || 80, session.term.rows || 24)
    );
    ws.binaryType = "arraybuffer";
    session.ws = ws;

    ws.addEventListener("open", () => {
      session.term.focus();
    });

    ws.addEventListener("message", (event) => {
      if (typeof event.data === "string") {
        try {
          const payload = JSON.parse(event.data);
          if (payload.type === "error") {
            session.term.writeln(`\r\n\x1b[31m${payload.message}\x1b[0m`);
            session.running = false;
            updateToolbar();
            renderTerminalTabs();
            markSidebarActive(session.scriptId);
          } else if (payload.type === "started") {
            session.term.writeln(`\r\n\x1b[36m▶ ${payload.script}\x1b[0m`);
            if (payload.log_file) {
              session.logFile = payload.log_file;
              session.term.writeln(`\x1b[90mlog: ${payload.log_file}\x1b[0m\r\n`);
            } else {
              session.logFile = null;
              session.term.writeln("");
            }
            updateToolbar();
          } else if (payload.type === "exit") {
            session.term.writeln(`\r\n\x1b[33m[exit ${payload.code}]\x1b[0m`);
            if (payload.log_file) {
              session.logFile = payload.log_file;
              session.term.writeln(`\x1b[90mlog: ${payload.log_file}\x1b[0m`);
            }
            session.running = false;
            updateToolbar();
            renderTerminalTabs();
            markSidebarActive(session.scriptId);
          }
        } catch (_err) {
          session.term.write(event.data);
        }
        return;
      }

      session.term.write(new Uint8Array(event.data));
    });

    ws.addEventListener("close", () => {
      if (session.ws === ws) {
        session.ws = null;
        session.running = false;
        updateToolbar();
        renderTerminalTabs();
        markSidebarActive(session.scriptId);
      }
    });

    ws.addEventListener("error", () => {
      session.term.writeln("\r\n\x1b[31mWebSocket connection failed\x1b[0m");
      session.running = false;
      updateToolbar();
      renderTerminalTabs();
      markSidebarActive(session.scriptId);
    });

    session.onDataDisposable = session.term.onData((data) => {
      if (session.ws && session.ws.readyState === WebSocket.OPEN) {
        session.ws.send(JSON.stringify({ type: "input", data }));
      }
    });
  }

  async function copyLogPath() {
    const session = getActiveSession();
    if (!session) {
      return;
    }
    if (!session.logFile) {
      session.term.writeln(
        "\r\n\x1b[33mNo log path yet — run the script first\x1b[0m",
      );
      return;
    }
    try {
      await navigator.clipboard.writeText(session.logFile);
      const previous = copySessionIdBtn.textContent;
      copySessionIdBtn.textContent = "Copied";
      setTimeout(() => {
        copySessionIdBtn.textContent = previous;
      }, 1000);
    } catch (_err) {
      session.term.writeln("\r\n\x1b[31mCould not copy log path\x1b[0m");
    }
  }

  function createScriptButton(script) {
    const li = document.createElement("li");
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "script-link";
    if (!script.runnable) {
      btn.classList.add("unsupported");
    }
    if (script.id === getActiveScriptId()) {
      btn.classList.add("active");
    }
    if (sessionsForScript(script.id).length > 0) {
      btn.classList.add("has-terminal");
    }
    if (sessionsForScript(script.id).some((session) => session.running)) {
      btn.classList.add("running");
    }

    btn.dataset.scriptId = script.id;
    const descHtml = script.description
      ? `<span class="desc">${escapeHtml(script.description)}</span>`
      : "";
    btn.innerHTML = `
      <span class="name">${escapeHtml(basename(script.id))}</span>
      ${descHtml}
      <span class="meta">${escapeHtml(script.id)} · ${escapeHtml(script.profile)} · ${escapeHtml(script.kind)}</span>
    `;

    btn.addEventListener("click", () => {
      openTerminalPanel(script.id, { runnable: Boolean(script.runnable) });
      if (!script.runnable) {
        const session = sessions.get(script.id);
        session.term.writeln(`\r\nUnsupported script type: ${script.id}`);
      }
    });

    li.appendChild(btn);
    return li;
  }

  function renderGroupPanel(group, items) {
    const panel = document.createElement("div");
    panel.className = "accordion-panel";
    panel.dataset.group = group;
    panel.hidden = true;

    const list = document.createElement("ul");
    list.className = "script-list";
    for (const script of items) {
      list.appendChild(createScriptButton(script));
    }

    panel.appendChild(list);
    return panel;
  }

  function setActiveGroup(group) {
    activeGroup = group;

    accordionNavEl.querySelectorAll(".accordion-tab").forEach((tab) => {
      const isActive = tab.dataset.group === group;
      tab.classList.toggle("active", isActive);
      tab.setAttribute("aria-expanded", isActive ? "true" : "false");
    });

    accordionContentEl.querySelectorAll(".accordion-panel").forEach((panel) => {
      panel.hidden = panel.dataset.group !== group;
    });

    const placeholder = accordionContentEl.querySelector(".accordion-placeholder");
    if (placeholder) {
      placeholder.hidden = Boolean(group);
    }
  }

  function renderScripts(scripts) {
    groupedScripts = groupScripts(scripts);
    accordionNavEl.innerHTML = "";
    accordionContentEl.innerHTML =
      '<p class="accordion-placeholder">Select a section</p>';

    for (const [group, items] of groupedScripts) {
      const tab = document.createElement("button");
      tab.type = "button";
      tab.className = "accordion-tab";
      tab.dataset.group = group;
      tab.setAttribute("aria-expanded", "false");
      tab.innerHTML = `
        <span class="accordion-label">${escapeHtml(group)}</span>
        <span class="accordion-count">${items.length}</span>
      `;

      tab.addEventListener("click", () => {
        if (activeGroup === group) {
          setActiveGroup(null);
          return;
        }
        setActiveGroup(group);
      });

      accordionNavEl.appendChild(tab);
      accordionContentEl.appendChild(renderGroupPanel(group, items));
    }

    if (activeGroup && groupedScripts.some(([group]) => group === activeGroup)) {
      setActiveGroup(activeGroup);
    }
  }

  async function loadScripts() {
    const res = await fetch("/api/scripts");
    const scripts = await res.json();
    renderScripts(scripts);
  }

  async function loadSession() {
    const res = await fetch("/api/session");
    const session = await res.json();
    const nextUrl = session.task_manager_url || "";
    taskManagerUrl = isAbsoluteHttpUrl(nextUrl) ? nextUrl : "";
    renderSession(session);
    if (activeView === "task-manager") {
      ensureEmbedLoaded(taskManagerFrame);
    }
  }

  runBtn.addEventListener("click", () => {
    runActiveScript();
  });

  if (mirrorGlobalLogCheck) {
    mirrorGlobalLogCheck.checked = readMirrorGlobalLogPref();
    mirrorGlobalLogCheck.addEventListener("change", () => {
      writeMirrorGlobalLogPref(mirrorGlobalLogCheck.checked);
    });
  }

  mainTabsEl.addEventListener("click", (event) => {
    const tab = event.target.closest(".main-tab");
    if (!tab || !mainTabsEl.contains(tab)) {
      return;
    }
    const view = tab.dataset.view;
    if (view && view !== activeView) {
      setActiveView(view);
    }
  });

  sessionIdBtn.addEventListener("click", () => {
    copyLogPath();
  });

  copySessionIdBtn.addEventListener("click", () => {
    copyLogPath();
  });

  stopBtn.addEventListener("click", () => {
    if (!activeSessionKey) {
      return;
    }
    stopSession(activeSessionKey, { writeStopped: true });
  });

  window.addEventListener("resize", () => {
    for (const session of sessions.values()) {
      if (session.hostEl.hidden) {
        continue;
      }
      session.fitAddon.fit();
      if (session.ws && session.ws.readyState === WebSocket.OPEN) {
        session.ws.send(
          JSON.stringify({
            type: "resize",
            cols: session.term.cols,
            rows: session.term.rows,
          })
        );
      }
    }
  });

  Promise.all([loadSession(), loadScripts()]).catch((err) => {
    terminalPlaceholderEl.textContent = `Failed to load dashboard: ${err}`;
  });
})();
