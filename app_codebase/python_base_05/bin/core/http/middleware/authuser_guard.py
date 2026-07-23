"""Wrap handlers registered through ``authuser_*`` on :class:`~core.http.contracts.register_route_contract.ApplicationRouteSink`.

Before the inner handler runs, we require a valid Bearer access JWT. On success we set
auth context on the request ContextVar. On failure we return JSON 401 and do not call the route.
"""

from __future__ import annotations

import logging
from typing import Callable

from starlette.responses import Response

from core.auth.verify_access import verify_bearer_or_raise
from core.errors.app_error import AppError
from core.http.request_context import get_current_request, set_auth_context

logger = logging.getLogger(__name__)


def _extract_bearer_token() -> str | None:
    request = get_current_request()
    if request is None:
        return None
    auth = request.headers.get("Authorization")
    if auth is None or not auth.lower().startswith("bearer "):
        return None
    token = auth[7:].strip()
    return token or None


def authuser_guard(inner: Callable[[], Response]) -> Callable[[], Response]:
    def wrapped() -> Response:
        request = get_current_request()
        path = request.url.path if request is not None else ""
        try:
            ctx = verify_bearer_or_raise(_extract_bearer_token())
        except AppError as err:
            logger.info("auth_failure reason=%s path=%s", err.code, path)
            return err.to_http_response()

        set_auth_context(user_id=ctx.user_id, claims=ctx.claims)
        return inner()

    return wrapped
