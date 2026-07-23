#!/usr/bin/env python3
# dash Open arcori automation dashboard in browser
"""wfrun dashboard — browser GUI alternative to the wfrun CLI script menu."""

from __future__ import annotations

import asyncio
import json
import os
import subprocess
import sys
import webbrowser
from collections.abc import Awaitable, Callable
from pathlib import Path

try:
    from aiohttp import WSMsgType, web
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


class SessionManager:
    def __init__(self) -> None:
        self._runner: PtyRunner | None = None
        self._log: RunLog | None = None
        self._lock = asyncio.Lock()

    async def stop_current(self) -> None:
        async with self._lock:
            runner = self._runner
            run_log = self._log
            self._runner = None
            self._log = None
            if runner is not None:
                await runner.terminate()
            if run_log is not None:
                run_log.close(exit_code=None)

    async def start(
        self,
        entry_id: str,
        root: Path,
        cols: int,
        rows: int,
        send_json: Callable[[dict[str, object]], Awaitable[None]],
        send_bytes: Callable[[bytes], Awaitable[None]],
    ) -> Path:
        await self.stop_current()

        catalog = discover_scripts(root)
        entry = resolve_script(root, entry_id, catalog)
        cmd = build_command(entry.path)
        child_env = env_for_script(entry)
        cwd = cwd_for_script()
        mode = os.environ.get("WFRUN_MODE", "local")

        log_path = log_path_for_script(entry.id)
        run_log = RunLog(log_path, entry.id, cmd, mode)
        runner = PtyRunner(cmd, child_env, cwd, cols=cols, rows=rows)

        async def on_output(data: bytes) -> None:
            run_log.write(data)
            await send_bytes(data)

        async def on_exit(code: int) -> None:
            run_log.close(exit_code=code)
            await send_json({"type": "exit", "code": code, "log_file": str(log_path)})
            async with self._lock:
                if self._runner is runner:
                    self._runner = None
                if self._log is run_log:
                    self._log = None

        async with self._lock:
            self._runner = runner
            self._log = run_log

        runner.start(on_output, on_exit)
        print(f"📝 Logging: {log_path}")
        await send_json(
            {
                "type": "started",
                "script": entry.id,
                "log_file": str(log_path),
            }
        )
        return log_path


def _dashboard_url(host: str, port: int) -> str:
    return f"http://{host}:{port}/"


async def handle_index(_request: web.Request) -> web.Response:
    return web.FileResponse(STATIC_DIR / "index.html")


async def handle_session(request: web.Request) -> web.Response:
    env_file = os.environ.get("WFRUN_ENV_FILE", "")
    return web.json_response(
        {
            "mode": os.environ.get("WFRUN_MODE", ""),
            "profile": os.environ.get("WFRUN_PROFILE", "backend"),
            "root": os.environ.get("WFRUN_ROOT", ""),
            "env_file": env_file,
            "env_file_name": Path(env_file).name if env_file else "",
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

    try:
        await manager.start(script_id, root, cols, rows, send_json, send_bytes)
    except ValueError as exc:
        await send_json({"type": "error", "message": str(exc)})
        await ws.close()
        return ws

    runner = manager._runner
    if runner is None:
        await ws.close()
        return ws

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
        await manager.stop_current()

    return ws


def create_app(root: Path) -> web.Application:
    app = web.Application()
    app["root"] = root
    app["session_manager"] = SessionManager()

    app.router.add_get("/", handle_index)
    app.router.add_get("/api/session", handle_session)
    app.router.add_post("/api/open-env-file", handle_open_env_file)
    app.router.add_get("/api/scripts", handle_scripts)
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
