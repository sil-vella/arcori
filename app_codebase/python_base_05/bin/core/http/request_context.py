"""Per-request context for sync handlers (replaces ``flask.request`` and ``flask.g``)."""

from __future__ import annotations

from contextvars import ContextVar
from typing import Any

from starlette.requests import Request

_request_ctx: ContextVar[Request | None] = ContextVar("request", default=None)
_auth_user_id_ctx: ContextVar[str | None] = ContextVar("auth_user_id", default=None)
_auth_claims_ctx: ContextVar[dict[str, Any] | None] = ContextVar("auth_claims", default=None)


def bind_request(request: Request) -> None:
    _request_ctx.set(request)


def get_current_request() -> Request | None:
    return _request_ctx.get()


def set_auth_context(*, user_id: str, claims: dict[str, Any]) -> None:
    _auth_user_id_ctx.set(user_id)
    _auth_claims_ctx.set(claims)


def get_auth_user_id() -> str | None:
    return _auth_user_id_ctx.get()


def get_auth_claims() -> dict[str, Any] | None:
    return _auth_claims_ctx.get()


def reset_request_context() -> None:
    _request_ctx.set(None)
    _auth_user_id_ctx.set(None)
    _auth_claims_ctx.set(None)


def get_client_ip() -> str | None:
    request = get_current_request()
    if request is None:
        return None
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        first = forwarded.split(",")[0].strip()
        if first:
            return first[:45]
    if request.client is not None and request.client.host:
        return request.client.host[:45]
    return None


def get_user_agent() -> str | None:
    request = get_current_request()
    if request is None:
        return None
    agent = request.headers.get("User-Agent")
    if not agent:
        return None
    return agent.strip()[:512] or None


def parse_upload_file(field_name: str = "avatar") -> dict[str, Any] | None:
    """Return uploaded file metadata stashed by the HTTP dispatcher."""
    request = get_current_request()
    if request is None:
        return None
    upload = getattr(request.state, "upload", None)
    if not isinstance(upload, dict):
        return None
    if upload.get("field_name") != field_name:
        return None
    return upload
