"""HTTP client for FastAPI → Dart service-tier calls."""

from __future__ import annotations

import logging
import os
from typing import Any

import httpx

from core.auth.auth_config import service_key

logger = logging.getLogger(__name__)

_DEFAULT_DART_URL = "http://127.0.0.1:8080"
_TIMEOUT_SECONDS = 5.0


def dart_service_url() -> str:
    raw = os.environ.get("DART_SERVICE_URL", "").strip()
    return raw or _DEFAULT_DART_URL


def _headers() -> dict[str, str]:
    return {
        "Content-Type": "application/json",
        "X-Service-Key": service_key(),
    }


def set_dart_drain_mode(enabled: bool) -> bool:
    """POST Dart /service/ops/drain-mode. Returns True if Dart acknowledged."""
    url = f"{dart_service_url().rstrip('/')}/service/ops/drain-mode"
    try:
        with httpx.Client(timeout=_TIMEOUT_SECONDS) as client:
            response = client.post(
                url,
                headers=_headers(),
                json={"enabled": enabled},
            )
        if response.status_code < 200 or response.status_code >= 300:
            logger.warning(
                "dart_drain_mode_failed status=%s body=%s",
                response.status_code,
                response.text[:200],
            )
            return False
        return True
    except Exception as exc:
        logger.warning("dart_drain_mode_error error=%s", type(exc).__name__)
        return False


def fetch_dart_drain_status() -> tuple[bool, dict[str, Any]]:
    """GET Dart /service/ops/drain-status. Returns (reachable, data)."""
    url = f"{dart_service_url().rstrip('/')}/service/ops/drain-status"
    try:
        with httpx.Client(timeout=_TIMEOUT_SECONDS) as client:
            response = client.get(url, headers=_headers())
        if response.status_code < 200 or response.status_code >= 300:
            logger.warning(
                "dart_drain_status_failed status=%s",
                response.status_code,
            )
            return False, {}
        body = response.json()
        if not isinstance(body, dict) or not body.get("ok"):
            return False, {}
        data = body.get("data")
        if not isinstance(data, dict):
            return False, {}
        return True, data
    except Exception as exc:
        logger.warning("dart_drain_status_error error=%s", type(exc).__name__)
        return False, {}
