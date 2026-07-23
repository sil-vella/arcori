"""Shared JSON format for every API response: either ``ok`` plus ``data``, or ``ok`` false plus an
``error`` object with ``code`` and ``message``.

The free functions ``json_ok`` and ``json_error`` build full ``JSONResponse`` objects with the
right content type. Route handlers use them directly or through :class:`JsonHttpResponses`; the
middleware and the “no such route” path use them too so clients always see the same structure.

``http_responses`` is a single object you can pass anywhere an :class:`~core.http.contracts.response_contract.HttpResponseContract` is expected.
"""

from typing import Any, Mapping

from starlette.responses import JSONResponse, Response

from core.http.contracts.response_contract import HttpResponseContract


def json_success_body(data: object | None) -> dict[str, Any]:
    return {"ok": True, "data": data}


def json_error_body(*, code: str, message: str) -> dict[str, Any]:
    return {"ok": False, "error": {"code": code, "message": message}}


def json_ok(data: object | None, *, status: int = 200) -> Response:
    body: Mapping[str, Any] = json_success_body(data)
    return JSONResponse(content=dict(body), status_code=status)


def json_error(*, code: str, message: str, status: int = 400) -> Response:
    body = json_error_body(code=code, message=message)
    return JSONResponse(content=body, status_code=status)


class JsonHttpResponses:
    """Thin wrapper so ``HttpResponseContract`` can be satisfied by delegating to ``json_ok`` /
    ``json_error`` below.
    """

    def json_ok(self, data: object | None, *, status: int = 200) -> Response:
        return json_ok(data, status=status)

    def json_error(self, *, code: str, message: str, status: int = 400) -> Response:
        return json_error(code=code, message=message, status=status)


http_responses: HttpResponseContract = JsonHttpResponses()
