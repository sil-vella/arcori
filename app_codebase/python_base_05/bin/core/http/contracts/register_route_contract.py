"""Let feature modules attach HTTP handlers without knowing how the global route table works.

The live implementation is ``application_routes`` in ``core.http.service.routes``. During startup,
``register_application_routes`` (from ``modules.module_registry``) calls into each feature, which
registers GET/POST/PUT/DELETE handlers here. The HTTP layer turns those into real routes with
the right prefix and guards where needed.

Pair this with :class:`~core.http.contracts.response_contract.HttpResponseContract` when a module
needs to format JSON replies.
"""

from typing import Callable, Protocol

from starlette.responses import Response


class ApplicationRouteSink(Protocol):
    """Register one handler per HTTP verb and path pattern.

    **Public** methods (``public_get``, …): ``path`` is the full URL path from the site root.

    **Authuser** methods (``authuser_get``, …): ``path`` is only the part after ``/authuser``. The
    framework adds ``/authuser`` and runs the Bearer-token check before your handler.

    **Service** methods (``service_get``, …): same idea for ``/service`` and the service-key check.

    Do not put ``/authuser`` or ``/service`` inside ``path`` for those groups—use something like
    ``/user/profile``, not ``/authuser/user/profile``.
    """

    def public_get(self, path: str, handler: Callable[[], Response]) -> None: ...

    def public_post(self, path: str, handler: Callable[[], Response]) -> None: ...

    def public_put(self, path: str, handler: Callable[[], Response]) -> None: ...

    def public_delete(self, path: str, handler: Callable[[], Response]) -> None: ...

    def authuser_get(self, path: str, handler: Callable[[], Response]) -> None: ...

    def authuser_post(self, path: str, handler: Callable[[], Response]) -> None: ...

    def authuser_put(self, path: str, handler: Callable[[], Response]) -> None: ...

    def authuser_delete(self, path: str, handler: Callable[[], Response]) -> None: ...

    def service_get(self, path: str, handler: Callable[[], Response]) -> None: ...

    def service_post(self, path: str, handler: Callable[[], Response]) -> None: ...

    def service_put(self, path: str, handler: Callable[[], Response]) -> None: ...

    def service_delete(self, path: str, handler: Callable[[], Response]) -> None: ...
