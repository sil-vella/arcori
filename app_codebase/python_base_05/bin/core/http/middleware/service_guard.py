"""Wrap handlers registered through ``service_*`` on :class:`~core.http.contracts.register_route_contract.ApplicationRouteSink`.

Before the inner handler runs, we require ``X-Service-Key`` to match ``SERVICE_KEY`` from the
environment (constant-time compare). If it is missing or wrong, we return JSON 403.
"""

from __future__ import annotations

import logging
from typing import Callable

from starlette.responses import Response

from core.auth.auth_config import is_production, service_key
from core.auth.verify_service_key import verify_service_key_or_raise
from core.errors.app_error import AppError
from core.errors.error_codes import FORBIDDEN
from core.http.request_context import get_current_request
from core.http.response.response import json_error

logger = logging.getLogger(__name__)


def service_guard(inner: Callable[[], Response]) -> Callable[[], Response]:
    def wrapped() -> Response:
        request = get_current_request()
        path = request.url.path if request is not None else ""
        if is_production() and not service_key():
            logger.error("auth_failure reason=service_key_not_configured path=%s", path)
            return json_error(
                code=FORBIDDEN.code,
                message="Service authentication unavailable",
                status=FORBIDDEN.http_status,
            )
        headers = request.headers if request is not None else {}
        try:
            verify_service_key_or_raise(headers.get("X-Service-Key"))
        except AppError as err:
            logger.info("auth_failure reason=%s path=%s", err.code, path)
            return err.to_http_response()
        return inner()

    return wrapped
