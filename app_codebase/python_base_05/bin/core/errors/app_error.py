"""AppError — raise in handlers; convert to HTTP envelope."""

from __future__ import annotations

from starlette.responses import Response

from core.errors.error_spec import ErrorSpec
from core.http.response.response import json_error
from core.ws.response.ws_response import encode_error


class AppError(Exception):
    def __init__(
        self,
        spec: ErrorSpec,
        *,
        message: str | None = None,
        headers: dict[str, str] | None = None,
    ) -> None:
        self.spec = spec
        self.message = message or spec.message
        self.headers = dict(headers or {})
        super().__init__(self.message)

    @property
    def code(self) -> str:
        return self.spec.code

    def to_http_response(self) -> Response:
        response = json_error(
            code=self.code,
            message=self.message,
            status=self.spec.http_status,
        )
        for key, value in self.headers.items():
            response.headers[key] = value
        return response

    def to_ws_frame(self) -> str:
        return encode_error(code=self.code, message=self.message)
