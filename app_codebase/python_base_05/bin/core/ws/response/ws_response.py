"""Encode/decode WebSocket JSON frames using the HTTP JSON envelope."""

from __future__ import annotations

import json
from typing import Any

from core.http.response.response import json_error_body, json_success_body


def encode_frame(*, ok: bool, data: object | None = None, code: str = "", message: str = "") -> str:
    if ok:
        body = json_success_body(data)
    else:
        body = json_error_body(code=code, message=message)
    return json.dumps(body)


def encode_ok(data: object | None) -> str:
    return encode_frame(ok=True, data=data)


def encode_error(*, code: str, message: str) -> str:
    return encode_frame(ok=False, code=code, message=message)


def parse_incoming(text: str) -> tuple[dict[str, Any] | None, dict[str, Any] | None]:
    """Return (data dict, error dict) — one will be set."""
    try:
        raw = json.loads(text)
    except json.JSONDecodeError:
        return None, {"code": "invalid_json", "message": "Message must be valid JSON"}
    if not isinstance(raw, dict):
        return None, {"code": "invalid_json", "message": "Message must be a JSON object"}
    if raw.get("ok") is True and isinstance(raw.get("data"), dict):
        return raw["data"], None
    if raw.get("ok") is False and isinstance(raw.get("error"), dict):
        err = raw["error"]
        return None, {
            "code": str(err.get("code", "invalid_message")),
            "message": str(err.get("message", "Invalid message")),
        }
    if "type" in raw and "channel" in raw:
        return raw, None
    return None, {"code": "invalid_message", "message": "Expected {type, channel} in data"}
