"""HTTP drain gate — 503 on non-allowlisted paths when drain_mode is on."""

from __future__ import annotations

from starlette.requests import Request
from starlette.responses import Response

from core.errors.app_error import AppError
from modules.ops.ops_errors import DRAIN_MODE
from modules.ops.ops_state import is_drain_mode

# Exact paths always allowed during drain (forks may extend via EXTRA_DRAIN_ALLOW_PREFIXES).
DRAIN_ALLOW_EXACT: frozenset[str] = frozenset(
    {
        "/health",
        "/service/health",
        "/service/auth/validate",
    }
)

# Prefixes always allowed during drain.
DRAIN_ALLOW_PREFIXES: tuple[str, ...] = (
    "/service/ops",
)

# Additional prefixes forks can append at import time.
EXTRA_DRAIN_ALLOW_PREFIXES: list[str] = []


def path_allowed_during_drain(path: str) -> bool:
    normalized = path.rstrip("/") or "/"
    if normalized in DRAIN_ALLOW_EXACT:
        return True
    prefixes = list(DRAIN_ALLOW_PREFIXES) + list(EXTRA_DRAIN_ALLOW_PREFIXES)
    for prefix in prefixes:
        if normalized == prefix or normalized.startswith(prefix + "/"):
            return True
    return False


def drain_blocked_response(request: Request) -> Response | None:
    """Return 503 response when draining and path is blocked; else None."""
    if request.method == "OPTIONS":
        return None
    try:
        if not is_drain_mode():
            return None
    except Exception:
        return None
    path = request.url.path
    if path_allowed_during_drain(path):
        return None
    return AppError(DRAIN_MODE).to_http_response()
