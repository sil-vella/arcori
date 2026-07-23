#!/usr/bin/env python3
"""Operator CLI for app-layer drain: enter, exit, status, poll."""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from typing import Any


def _base_url() -> str:
    raw = os.environ.get("OPS_DRAIN_BASE_URL", "").strip()
    if not raw:
        print(
            "OPS_DRAIN_BASE_URL is required (e.g. http://127.0.0.1:8000)",
            file=sys.stderr,
        )
        sys.exit(2)
    return raw.rstrip("/")


def _service_key() -> str:
    key = os.environ.get("SERVICE_KEY", "").strip()
    if not key:
        print("SERVICE_KEY is required", file=sys.stderr)
        sys.exit(2)
    return key


def _request(method: str, path: str) -> dict[str, Any]:
    url = f"{_base_url()}{path}"
    req = urllib.request.Request(
        url,
        method=method,
        headers={
            "Content-Type": "application/json",
            "X-Service-Key": _service_key(),
        },
        data=b"{}" if method == "POST" else None,
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            body = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        try:
            body = json.loads(raw)
        except json.JSONDecodeError:
            print(f"HTTP {exc.code}: {raw}", file=sys.stderr)
            sys.exit(1)
        print(json.dumps(body, indent=2))
        sys.exit(1)
    except urllib.error.URLError as exc:
        print(f"request failed: {exc.reason}", file=sys.stderr)
        sys.exit(1)

    if not isinstance(body, dict) or not body.get("ok"):
        print(json.dumps(body, indent=2))
        sys.exit(1)
    data = body.get("data")
    if not isinstance(data, dict):
        print(json.dumps(body, indent=2))
        sys.exit(1)
    return data


def cmd_enter(_: argparse.Namespace) -> None:
    data = _request("POST", "/service/ops/enter-drain")
    print(json.dumps(data, indent=2))


def cmd_exit(_: argparse.Namespace) -> None:
    data = _request("POST", "/service/ops/exit-drain")
    print(json.dumps(data, indent=2))


def cmd_status(_: argparse.Namespace) -> None:
    data = _request("GET", "/service/ops/drain-status")
    print(json.dumps(data, indent=2))


def cmd_poll(args: argparse.Namespace) -> None:
    deadline = time.monotonic() + max(1, args.max_wait)
    stable_needed = max(1, args.stable_polls)
    interval = max(1, args.interval)
    consecutive = 0
    last: dict[str, Any] | None = None

    while time.monotonic() < deadline:
        last = _request("GET", "/service/ops/drain-status")
        ready = bool(last.get("ready"))
        print(json.dumps(last, indent=2))
        if ready:
            consecutive += 1
            if consecutive >= stable_needed:
                print(f"ready after {consecutive} consecutive clear poll(s)")
                return
        else:
            consecutive = 0
        time.sleep(interval)

    print(
        "poll timed out — abort: run exit-drain, deactivate edge drain, "
        "do NOT stop containers",
        file=sys.stderr,
    )
    if last is not None:
        print(json.dumps(last, indent=2), file=sys.stderr)
    sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser(description="App-layer drain operator CLI")
    sub = parser.add_subparsers(dest="command", required=True)

    p_enter = sub.add_parser("enter", help="Enable drain (FastAPI + Dart)")
    p_enter.set_defaults(func=cmd_enter)

    p_exit = sub.add_parser("exit", help="Disable drain")
    p_exit.set_defaults(func=cmd_exit)

    p_status = sub.add_parser("status", help="Show drain readiness")
    p_status.set_defaults(func=cmd_status)

    p_poll = sub.add_parser("poll", help="Poll until ready or timeout")
    p_poll.add_argument("--max-wait", type=int, default=1800)
    p_poll.add_argument("--interval", type=int, default=15)
    p_poll.add_argument("--stable-polls", type=int, default=2)
    p_poll.set_defaults(func=cmd_poll)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
