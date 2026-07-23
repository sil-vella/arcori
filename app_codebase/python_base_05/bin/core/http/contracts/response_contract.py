"""Define what “sending JSON back” looks like to feature code.

Handlers often receive an object that implements :class:`HttpResponseContract` so they can return
success payloads or structured errors without importing FastAPI or the concrete helpers in
``core.http.response.response``. That makes tests easier and keeps imports small.

The running app typically passes :class:`~core.http.response.response.JsonHttpResponses` (or the
module-level ``http_responses`` instance), which matches this interface.
"""

from typing import Protocol

from starlette.responses import Response


class HttpResponseContract(Protocol):
    """Two methods: one for a normal JSON body with optional HTTP status, one for errors with a
    short machine-readable ``code`` and a human ``message``.
    """

    def json_ok(self, data: object | None, *, status: int = 200) -> Response: ...

    def json_error(self, *, code: str, message: str, status: int = 400) -> Response: ...
