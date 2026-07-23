(() => {
  const sessionMetaEl = document.getElementById("session-meta");
  const accordionNavEl = document.getElementById("accordion-nav");
  const accordionContentEl = document.getElementById("accordion-content");
  const activeScriptEl = document.getElementById("active-script");
  const stopBtn = document.getElementById("stop-btn");
  const terminalHost = document.getElementById("terminal");

  const term = new Terminal({
    cursorBlink: true,
    fontFamily: "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace",
    fontSize: 13,
    theme: {
      background: "#0f1117",
      foreground: "#e6eaf2",
    },
  });
  const fitAddon = new FitAddon.FitAddon();
  term.loadAddon(fitAddon);
  term.open(terminalHost);
  fitAddon.fit();

  let ws = null;
  let activeScriptId = null;
  let activeGroup = null;
  let running = false;
  let groupedScripts = [];

  function setRunning(isRunning) {
    running = isRunning;
    stopBtn.disabled = !isRunning;
  }

  function closeSocket() {
    if (ws) {
      ws.close();
      ws = null;
    }
    setRunning(false);
  }

  function renderSession(session) {
    const envName = session.env_file_name || session.env_file.split("/").pop();
    sessionMetaEl.replaceChildren();

    const modeRow = document.createElement("div");
    modeRow.innerHTML = `<strong>mode</strong> ${session.mode}`;
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
        term.writeln("\r\n\x1b[31mCould not open env file\x1b[0m");
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

  function createScriptButton(script) {
    const li = document.createElement("li");
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "script-link";
    if (!script.runnable) {
      btn.classList.add("unsupported");
    }
    if (script.id === activeScriptId) {
      btn.classList.add("active");
    }

    const basename = script.id.split("/").pop();
    btn.dataset.scriptId = script.id;
    const descHtml = script.description
      ? `<span class="desc">${script.description}</span>`
      : "";
    btn.innerHTML = `
      <span class="name">${basename}</span>
      ${descHtml}
      <span class="meta">${script.id} · ${script.profile} · ${script.kind}</span>
    `;

    btn.addEventListener("click", () => {
      if (!script.runnable) {
        term.writeln(`\r\nUnsupported script type: ${script.id}`);
        return;
      }
      if (running && script.id !== activeScriptId) {
        const ok = window.confirm(
          "A script is still running. Stop it and start the selected script?"
        );
        if (!ok) {
          return;
        }
      }
      runScript(script.id);
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
    accordionContentEl.innerHTML = '<p class="accordion-placeholder">Select a section</p>';

    for (const [group, items] of groupedScripts) {
      const tab = document.createElement("button");
      tab.type = "button";
      tab.className = "accordion-tab";
      tab.dataset.group = group;
      tab.setAttribute("aria-expanded", "false");
      tab.innerHTML = `
        <span class="accordion-label">${group}</span>
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
    renderSession(session);
  }

  function wsUrl(scriptId) {
    const cols = term.cols || 80;
    const rows = term.rows || 24;
    const params = new URLSearchParams({
      script: scriptId,
      cols: String(cols),
      rows: String(rows),
    });
    const proto = window.location.protocol === "https:" ? "wss:" : "ws:";
    return `${proto}//${window.location.host}/ws/run?${params.toString()}`;
  }

  function markActive(scriptId) {
    activeScriptId = scriptId;
    activeScriptEl.textContent = scriptId;
    document.querySelectorAll(".script-link").forEach((el) => {
      el.classList.toggle("active", el.dataset.scriptId === scriptId);
    });
  }

  function runScript(scriptId) {
    closeSocket();
    term.reset();
    markActive(scriptId);
    setRunning(true);

    ws = new WebSocket(wsUrl(scriptId));
    ws.binaryType = "arraybuffer";

    ws.addEventListener("open", () => {
      term.focus();
    });

    ws.addEventListener("message", (event) => {
      if (typeof event.data === "string") {
        try {
          const payload = JSON.parse(event.data);
          if (payload.type === "error") {
            term.writeln(`\r\n\x1b[31m${payload.message}\x1b[0m`);
            setRunning(false);
          } else if (payload.type === "started") {
            term.writeln(`\r\n\x1b[36m▶ ${payload.script}\x1b[0m`);
            if (payload.log_file) {
              term.writeln(`\x1b[90mlog: ${payload.log_file}\x1b[0m\r\n`);
            } else {
              term.writeln("");
            }
          } else if (payload.type === "exit") {
            term.writeln(`\r\n\x1b[33m[exit ${payload.code}]\x1b[0m`);
            if (payload.log_file) {
              term.writeln(`\x1b[90mlog: ${payload.log_file}\x1b[0m`);
            }
            setRunning(false);
          }
        } catch (_err) {
          term.write(event.data);
        }
        return;
      }

      const bytes = new Uint8Array(event.data);
      term.write(bytes);
    });

    ws.addEventListener("close", () => {
      setRunning(false);
    });

    ws.addEventListener("error", () => {
      term.writeln("\r\n\x1b[31mWebSocket connection failed\x1b[0m");
      setRunning(false);
    });

    term.onData((data) => {
      if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ type: "input", data }));
      }
    });
  }

  stopBtn.addEventListener("click", () => {
    closeSocket();
    term.writeln("\r\n\x1b[33m[stopped by user]\x1b[0m");
  });

  window.addEventListener("resize", () => {
    fitAddon.fit();
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ type: "resize", cols: term.cols, rows: term.rows }));
    }
  });

  Promise.all([loadSession(), loadScripts()]).catch((err) => {
    term.writeln(`\r\nFailed to load dashboard: ${err}`);
  });
})();
