#!/usr/bin/env python3
# dash Open arcori automation dashboard in browser
"""wfrun dashboard — browser GUI alternative to the wfrun CLI script menu."""

from __future__ import annotations

import asyncio
import json
import os
import re
import subprocess
import sys
import webbrowser
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from pathlib import Path

try:
    from aiohttp import ClientSession, ClientTimeout, WSMsgType, web
except ImportError:
    print(
        "❌ Missing dependency: aiohttp\n"
        "   Install once: pip install -r automation/dashboard/requirements.txt",
        file=sys.stderr,
    )
    sys.exit(1)

from env_for_script import cwd_for_script, env_for_script
from pty_runner import PtyRunner
from run_log import LOGS_DIR, RunLog, log_path_for_script
from script_discovery import build_command, discover_scripts, resolve_script

SCRIPT_DIR = Path(__file__).resolve().parent
STATIC_DIR = SCRIPT_DIR / "static"
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8765
# Same-origin path prefix so the Task Manager iframe shares the dashboard origin
# (cross-site cookies break PHP session + CSRF login inside the iframe).
TM_PROXY_PREFIX = "/tm"
_TM_ABS_ATTR_RE = re.compile(
    rb'(?i)(\b(?:href|src|action|formaction|data-src|poster)\s*=\s*[\'"])/(?!tm/)'
)
_TM_CSS_URL_RE = re.compile(rb"""(?i)(url\(\s*['"]?)/(?!tm/)""")
_TM_PROXY_TIMEOUT = ClientTimeout(total=120)


def require_wfrun() -> Path:
    root = os.environ.get("WFRUN_ROOT", "").strip()
    mode = os.environ.get("WFRUN_MODE", "").strip()
    env_file = os.environ.get("WFRUN_ENV_FILE", "").strip()
    if not root or not mode or not env_file:
        print(
            "❌ Run via wfrun — this script expects WFRUN_ROOT, WFRUN_MODE, WFRUN_ENV_FILE.",
            file=sys.stderr,
        )
        sys.exit(1)
    return Path(root)


@dataclass
class ScriptSession:
    script_id: str
    runner: PtyRunner
    run_log: RunLog
    log_path: Path


def _rel_log_path(log_path: Path, root: Path) -> str:
    try:
        return log_path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return str(log_path)


class SessionManager:
    """One PTY session per script id — multiple scripts can run concurrently."""

    def __init__(self) -> None:
        self._sessions: dict[str, ScriptSession] = {}
        self._lock = asyncio.Lock()

    async def stop_session(self, session: ScriptSession) -> None:
        async with self._lock:
            current = self._sessions.get(session.script_id)
            if current is not session:
                return
            self._sessions.pop(session.script_id, None)
        await session.runner.terminate()
        session.run_log.close(exit_code=None)

    async def stop(self, script_id: str) -> None:
        async with self._lock:
            session = self._sessions.pop(script_id, None)
        if session is None:
            return
        await session.runner.terminate()
        session.run_log.close(exit_code=None)

    async def start(
        self,
        entry_id: str,
        root: Path,
        cols: int,
        rows: int,
        send_json: Callable[[dict[str, object]], Awaitable[None]],
        send_bytes: Callable[[bytes], Awaitable[None]],
    ) -> tuple[ScriptSession, Path]:
        await self.stop(entry_id)

        catalog = discover_scripts(root)
        entry = resolve_script(root, entry_id, catalog)
        cmd = build_command(entry.path)
        child_env = env_for_script(entry)
        cwd = cwd_for_script()
        mode = os.environ.get("WFRUN_MODE", "local")

        log_path = log_path_for_script(entry.id)
        log_rel = _rel_log_path(log_path, root)
        run_log = RunLog(log_path, entry.id, cmd, mode)
        runner = PtyRunner(cmd, child_env, cwd, cols=cols, rows=rows)
        session = ScriptSession(
            script_id=entry.id,
            runner=runner,
            run_log=run_log,
            log_path=log_path,
        )

        async def on_output(data: bytes) -> None:
            run_log.write(data)
            await send_bytes(data)

        async def on_exit(code: int) -> None:
            run_log.close(exit_code=code)
            await send_json(
                {"type": "exit", "code": code, "log_file": log_rel}
            )
            async with self._lock:
                if self._sessions.get(entry.id) is session:
                    self._sessions.pop(entry.id, None)

        async with self._lock:
            self._sessions[entry.id] = session

        runner.start(on_output, on_exit)
        print(f"📝 Logging: {log_rel}")
        await send_json(
            {
                "type": "started",
                "script": entry.id,
                "log_file": log_rel,
            }
        )
        return session, log_path


def _dashboard_url(host: str, port: int) -> str:
    return f"http://{host}:{port}/"


async def handle_index(_request: web.Request) -> web.Response:
    return web.FileResponse(STATIC_DIR / "index.html")


def _env_from_wfrun_file(key: str) -> str:
    """Prefer process env; fall back to WFRUN_ENV_FILE key=value lines."""
    value = os.environ.get(key, "").strip()
    if value:
        return value
    env_file = os.environ.get("WFRUN_ENV_FILE", "").strip()
    if not env_file:
        return ""
    path = Path(env_file)
    if not path.is_file():
        return ""
    try:
        for raw in path.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            name, _, val = line.partition("=")
            if name.strip() != key:
                continue
            val = val.strip()
            if len(val) >= 2 and val[0] == val[-1] and val[0] in "\"'":
                val = val[1:-1]
            return val.strip()
    except OSError:
        return ""
    return ""


def _task_manager_base_url() -> str:
    """Origin for Task Manager (no trailing slash). Prefer TASK_MANAGER_BASE_URL."""
    base = _env_from_wfrun_file("TASK_MANAGER_BASE_URL").rstrip("/")
    if base:
        return base
    # Legacy host:port (pre-domain deploy)
    host = _env_from_wfrun_file("TASK_MANAGER_HOST")
    port = _env_from_wfrun_file("TASK_MANAGER_PORT")
    if host and port:
        return f"http://{host}:{port}"
    if host:
        return f"http://{host}"
    return ""


def _task_manager_embed_path() -> str:
    slug = _env_from_wfrun_file("TASK_MANAGER_SLUG")
    if not _task_manager_base_url() or not slug:
        return ""
    return f"{TM_PROXY_PREFIX}/content/label.php?slug={slug}&embed=1"


def _task_manager_url(request: web.Request | None = None) -> str:
    """Dashboard same-origin embed URL (via /tm proxy), not the remote origin."""
    path = _task_manager_embed_path()
    if not path:
        return ""
    if request is not None:
        return f"{request.url.scheme}://{request.host}{path}"
    host = os.environ.get("WFRUN_DASHBOARD_HOST", DEFAULT_HOST).strip() or DEFAULT_HOST
    port = int(os.environ.get("WFRUN_DASHBOARD_PORT", str(DEFAULT_PORT)))
    return f"http://{host}:{port}{path}"


def _rewrite_tm_set_cookie(value: str) -> str:
    parts: list[str] = []
    saw_path = False
    for raw in value.split(";"):
        part = raw.strip()
        if not part:
            continue
        lower = part.lower()
        if lower.startswith("domain="):
            continue
        if lower.startswith("path="):
            parts.append(f"Path={TM_PROXY_PREFIX}")
            saw_path = True
            continue
        if lower == "secure":
            continue
        parts.append(part)
    if not saw_path:
        parts.append(f"Path={TM_PROXY_PREFIX}")
    return "; ".join(parts)


def _rewrite_tm_location(location: str, remote_base: str) -> str:
    if location.startswith(remote_base):
        location = location[len(remote_base) :] or "/"
    if location.startswith("//"):
        return location
    if location.startswith("/") and not location.startswith(f"{TM_PROXY_PREFIX}/"):
        if location == TM_PROXY_PREFIX:
            return location
        return f"{TM_PROXY_PREFIX}{location}"
    return location


def _rewrite_tm_body(body: bytes, remote_base: str) -> bytes:
    remote = remote_base.encode("ascii", errors="ignore")
    if remote:
        body = body.replace(remote + b"/", (TM_PROXY_PREFIX + "/").encode("ascii"))
        body = body.replace(remote, TM_PROXY_PREFIX.encode("ascii"))
    body = _TM_ABS_ATTR_RE.sub(rb"\1" + (TM_PROXY_PREFIX + "/").encode("ascii"), body)
    body = _TM_CSS_URL_RE.sub(rb"\1" + (TM_PROXY_PREFIX + "/").encode("ascii"), body)
    # Avoid accidental /tm/tm/ if upstream already used the prefix string
    doubled = (TM_PROXY_PREFIX + TM_PROXY_PREFIX + "/").encode("ascii")
    body = body.replace(doubled, (TM_PROXY_PREFIX + "/").encode("ascii"))
    return body


async def handle_tm_proxy(request: web.Request) -> web.StreamResponse:
    remote_base = _task_manager_base_url()
    if not remote_base:
        return web.Response(text="Task Manager not configured", status=503)

    path = request.match_info.get("path", "").lstrip("/")
    target = f"{remote_base}/{path}" if path else f"{remote_base}/"
    if request.query_string:
        target = f"{target}?{request.query_string}"

    fwd_headers: dict[str, str] = {}
    for key, value in request.headers.items():
        lower = key.lower()
        if lower in {
            "host",
            "content-length",
            "connection",
            "transfer-encoding",
            "keep-alive",
            "proxy-authenticate",
            "proxy-authorization",
            "te",
            "trailers",
            "upgrade",
        }:
            continue
        fwd_headers[key] = value

    body_in = await request.read()
    session: ClientSession = request.app["tm_http"]
    try:
        async with session.request(
            request.method,
            target,
            headers=fwd_headers,
            data=body_in if body_in else None,
            allow_redirects=False,
        ) as upstream:
            raw = await upstream.read()
            content_type = upstream.headers.get("Content-Type", "")
            if any(
                token in content_type
                for token in ("text/html", "text/css", "javascript", "json")
            ):
                raw = _rewrite_tm_body(raw, remote_base)

            out = web.Response(body=raw, status=upstream.status)
            for key, value in upstream.headers.items():
                lower = key.lower()
                if lower in {
                    "transfer-encoding",
                    "content-encoding",
                    "content-length",
                    "connection",
                    "x-frame-options",
                }:
                    continue
                if lower == "set-cookie":
                    out.headers.add("Set-Cookie", _rewrite_tm_set_cookie(value))
                    continue
                if lower == "location":
                    out.headers[key] = _rewrite_tm_location(value, remote_base)
                    continue
                if lower == "content-security-policy":
                    continue
                out.headers[key] = value
            out.headers["Content-Security-Policy"] = "frame-ancestors *"
            return out
    except Exception as exc:  # noqa: BLE001 — surface upstream failures to the iframe
        return web.Response(
            text=f"Task Manager proxy error: {exc}",
            status=502,
            content_type="text/plain",
        )


async def handle_session(request: web.Request) -> web.Response:
    env_file = os.environ.get("WFRUN_ENV_FILE", "")
    base = _task_manager_base_url()
    slug = _env_from_wfrun_file("TASK_MANAGER_SLUG")
    task_manager_url = _task_manager_url(request)
    return web.json_response(
        {
            "mode": os.environ.get("WFRUN_MODE", ""),
            "profile": os.environ.get("WFRUN_PROFILE", "backend"),
            "root": os.environ.get("WFRUN_ROOT", ""),
            "env_file": env_file,
            "env_file_name": Path(env_file).name if env_file else "",
            "task_manager_base_url": base,
            "task_manager_slug": slug,
            "task_manager_url": task_manager_url,
        }
    )


def _open_path_in_editor(path: Path) -> None:
    path_str = str(path)
    if sys.platform == "darwin":
        subprocess.Popen(["open", "-e", path_str], close_fds=True)
        return
    if sys.platform.startswith("linux"):
        subprocess.Popen(["xdg-open", path_str], close_fds=True)
        return
    os.startfile(path_str)  # type: ignore[attr-defined]


async def handle_open_env_file(_request: web.Request) -> web.Response:
    env_file = os.environ.get("WFRUN_ENV_FILE", "").strip()
    path = Path(env_file)
    if not env_file or not path.is_file():
        return web.json_response({"ok": False, "error": "Env file not found"}, status=404)

    try:
        await asyncio.to_thread(_open_path_in_editor, path)
    except OSError as exc:
        return web.json_response({"ok": False, "error": str(exc)}, status=500)

    return web.json_response({"ok": True, "path": str(path)})


async def handle_scripts(request: web.Request) -> web.Response:
    root: Path = request.app["root"]
    entries = discover_scripts(root)
    return web.json_response([entry.to_dict() for entry in entries])


async def handle_ws_run(request: web.Request) -> web.WebSocketResponse:
    ws = web.WebSocketResponse(autoclose=True, autoping=True, heartbeat=30)
    await ws.prepare(request)

    root: Path = request.app["root"]
    manager: SessionManager = request.app["session_manager"]
    script_id = request.query.get("script", "").strip()
    cols = int(request.query.get("cols", "80"))
    rows = int(request.query.get("rows", "24"))

    if not script_id:
        await ws.send_json({"type": "error", "message": "Missing script query parameter"})
        await ws.close()
        return ws

    async def send_json(payload: dict[str, object]) -> None:
        if not ws.closed:
            await ws.send_json(payload)

    async def send_bytes(data: bytes) -> None:
        if not ws.closed:
            await ws.send_bytes(data)

    session: ScriptSession | None = None
    try:
        session, _log_path = await manager.start(
            script_id, root, cols, rows, send_json, send_bytes
        )
    except ValueError as exc:
        await send_json({"type": "error", "message": str(exc)})
        await ws.close()
        return ws

    runner = session.runner

    try:
        async for msg in ws:
            if msg.type == WSMsgType.TEXT:
                try:
                    payload = json.loads(msg.data)
                except json.JSONDecodeError:
                    continue
                msg_type = payload.get("type")
                if msg_type == "input":
                    data = payload.get("data", "")
                    if isinstance(data, str):
                        runner.write_input(data.encode("utf-8"))
                elif msg_type == "resize":
                    c = int(payload.get("cols", cols))
                    r = int(payload.get("rows", rows))
                    runner.resize(c, r)
            elif msg.type == WSMsgType.BINARY:
                runner.write_input(msg.data)
            elif msg.type in {WSMsgType.CLOSE, WSMsgType.ERROR}:
                break
    finally:
        await manager.stop_session(session)

    return ws


def create_app(root: Path) -> web.Application:
    app = web.Application()
    app["root"] = root
    app["session_manager"] = SessionManager()

    async def _open_tm_http(application: web.Application) -> None:
        application["tm_http"] = ClientSession(timeout=_TM_PROXY_TIMEOUT)

    async def _close_tm_http(application: web.Application) -> None:
        session = application.get("tm_http")
        if session is not None and not session.closed:
            await session.close()

    app.on_startup.append(_open_tm_http)
    app.on_cleanup.append(_close_tm_http)

    app.router.add_get("/", handle_index)
    app.router.add_get("/api/session", handle_session)
    app.router.add_post("/api/open-env-file", handle_open_env_file)
    app.router.add_get("/api/scripts", handle_scripts)
    app.router.add_route("*", TM_PROXY_PREFIX, handle_tm_proxy)
    app.router.add_route("*", TM_PROXY_PREFIX + "/{path:.*}", handle_tm_proxy)
    app.router.add_get("/ws/run", handle_ws_run)
    app.router.add_static("/static/", STATIC_DIR, show_index=False)
    return app


def main() -> None:
    root = require_wfrun()
    host = os.environ.get("WFRUN_DASHBOARD_HOST", DEFAULT_HOST).strip() or DEFAULT_HOST
    port = int(os.environ.get("WFRUN_DASHBOARD_PORT", str(DEFAULT_PORT)))

    if host not in {"127.0.0.1", "localhost"}:
        print(f"⚠️  Binding to {host} — dashboard is intended for localhost use only.")

    url = _dashboard_url(host, port)
    mode = os.environ.get("WFRUN_MODE", "local")

    print(f"🖥️  wfrun dashboard ({mode})")
    print(f"   {url}")
    tm_url = _task_manager_url()
    if tm_url:
        print(f"   Task Manager: {tm_url}")
    else:
        print(
            "   Task Manager: unset "
            "(need TASK_MANAGER_BASE_URL + TASK_MANAGER_SLUG in .env.local or .env.prod)"
        )
    print(f"   Logs: {LOGS_DIR}")
    print("   CLI wfrun remains available — this GUI is an alternative.")
    print("   Press Ctrl+C here to stop the server.")

    try:
        webbrowser.open(url)
    except OSError:
        pass

    app = create_app(root)
    web.run_app(app, host=host, port=port, print=None)


if __name__ == "__main__":
    main()
