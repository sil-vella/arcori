"""Production runtime helpers: env-driven thresholds and FastAPI observability hooks."""

from __future__ import annotations

import logging
import os
import time
from typing import TYPE_CHECKING

from fastapi import FastAPI, Request
from starlette.responses import Response

from core.auth.auth_config import cors_allowed_origins
from core.errors.app_error import AppError
from core.errors.error_codes import INTERNAL_ERROR
from core.http.middleware.drain_guard import drain_blocked_response
from core.http.middleware.rate_limit_guard import rate_limit_blocked_response
from core.utils.dev_logger import customlog

if TYPE_CHECKING:
    pass

logger = logging.getLogger(__name__)

LOGGING_SWITCH = False


def slow_request_threshold_ms() -> int:
    """Log a warning when a request exceeds this duration (default 5s)."""
    return int(os.environ.get("SLOW_REQUEST_THRESHOLD_MS", "5000"))


def log_tracebacks_enabled() -> bool:
    """When true, 500 handlers emit full tracebacks (break-glass debugging)."""
    return os.environ.get("LOG_TRACEBACKS", "").lower() in ("1", "true", "yes")


def metrics_allowed_cidrs() -> tuple[str, ...]:
    """CIDR allowlist for /metrics when exposed (future use)."""
    raw = os.environ.get("METRICS_ALLOWED_CIDRS", "127.0.0.1,172.16.0.0/12")
    return tuple(part.strip() for part in raw.split(",") if part.strip())


def _matching_cors_origin(request: Request) -> str | None:
    origin = request.headers.get("Origin")
    if not origin:
        return None
    allowed = cors_allowed_origins()
    if origin in allowed:
        return origin
    return None


def _apply_cors_headers(request: Request, response: Response) -> Response:
    origin = _matching_cors_origin(request)
    if origin:
        response.headers["Access-Control-Allow-Origin"] = origin
        response.headers["Vary"] = "Origin"
        response.headers["Access-Control-Allow-Headers"] = (
            "Authorization, Content-Type, X-Service-Key"
        )
        response.headers["Access-Control-Allow-Methods"] = (
            "GET, POST, PUT, DELETE, OPTIONS"
        )
    return response


def configure_production(app: FastAPI) -> None:
    """Register slow-request logging, CORS, and safe 500 handling on [app]."""
    if getattr(app, "_wf_production_configured", False):
        return
    app._wf_production_configured = True  # type: ignore[attr-defined]

    @app.middleware("http")
    async def _production_middleware(request: Request, call_next):
        if request.method == "OPTIONS":
            origin = _matching_cors_origin(request)
            if origin:
                response = Response(status_code=204)
                return _apply_cors_headers(request, response)

        blocked = drain_blocked_response(request)
        if blocked is not None:
            return _apply_cors_headers(request, blocked)

        limited = rate_limit_blocked_response(request)
        if limited is not None:
            return _apply_cors_headers(request, limited)

        request.state._wf_request_start = time.perf_counter()
        response = await call_next(request)

        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response = _apply_cors_headers(request, response)

        start = getattr(request.state, "_wf_request_start", None)
        if start is not None:
            elapsed_ms = (time.perf_counter() - start) * 1000.0
            threshold = slow_request_threshold_ms()
            if elapsed_ms >= threshold:
                if LOGGING_SWITCH:
                    customlog(
                        f"slow_request method={request.method} path={request.url.path} "
                        f"status={response.status_code} duration_ms={elapsed_ms:.2f}"
                    )
                logger.warning(
                    "slow_request method=%s path=%s status=%s duration_ms=%.2f",
                    request.method,
                    request.url.path,
                    response.status_code,
                    elapsed_ms,
                )
        return response

    @app.exception_handler(AppError)
    async def _handle_app_error(request: Request, err: AppError) -> Response:
        logger.info("app_error code=%s path=%s", err.code, request.url.path)
        return err.to_http_response()

    @app.exception_handler(Exception)
    async def _handle_internal_error(request: Request, err: Exception) -> Response:
        if isinstance(err, AppError):
            return err.to_http_response()
        logger.error(
            "internal_error type=%s path=%s",
            type(err).__name__,
            request.url.path,
        )
        if log_tracebacks_enabled():
            logger.exception("internal_error traceback")
        return AppError(INTERNAL_ERROR).to_http_response()
