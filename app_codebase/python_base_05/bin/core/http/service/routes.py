"""Store handlers keyed by HTTP method plus path, and dispatch each request to the right one.

Registration goes through ``application_routes``, which implements
:class:`~core.http.contracts.register_route_contract.ApplicationRouteSink`. There are three
groups: **public** routes use the URL path you pass in as-is; **authuser** routes are served under
``/authuser/...`` and wrap the handler so a Bearer token must be present first; **service**
routes are under ``/service/...`` and require a service key header first. Internally we normalize
paths (for example trailing slashes) so lookups stay consistent.

If no handler matches, the app answers with a JSON error and HTTP 404. ``reset_route_registry``
and ``build_application_handler`` are used from ``core.http.http_app.createHttpHandler`` when the
app starts.
"""

from typing import Callable

import os

from fastapi import FastAPI
from starlette.concurrency import run_in_threadpool
from starlette.requests import Request
from starlette.responses import Response
from starlette.staticfiles import StaticFiles

from core.http.contracts.register_route_contract import ApplicationRouteSink
from core.http.middleware.authuser_guard import authuser_guard
from core.http.middleware.service_guard import service_guard
from core.http.request_context import bind_request, reset_request_context
from core.http.response.response import json_error

_PREFIX_AUTHUSER = "/authuser"
_PREFIX_SERVICE = "/service"


def reset_route_registry() -> None:
    """Drop all registered routes (call before registering again, e.g. on startup)."""
    _the_registry.clear()


def build_application_handler() -> FastAPI:
    """Return a FastAPI app whose routes are looked up from the in-memory registry."""
    app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)
    _mount_media(app)

    @app.api_route(
        "/{full_path:path}",
        methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        include_in_schema=False,
    )
    async def _dispatch(request: Request, full_path: str = "") -> Response:
        bind_request(request)
        try:
            if request.method in ("POST", "PUT", "PATCH"):
                content_type = request.headers.get("content-type", "")
                if "application/json" in content_type.lower():
                    try:
                        data = await request.json()
                        request.state.json_body = data if isinstance(data, dict) else {}
                    except Exception:
                        request.state.json_body = {}
                elif "multipart/form-data" in content_type.lower():
                    request.state.json_body = {}
                    try:
                        form = await request.form()
                        upload = form.get("avatar")
                        if upload is not None and hasattr(upload, "read"):
                            raw = await upload.read()
                            if raw:
                                request.state.upload = {
                                    "field_name": "avatar",
                                    "filename": getattr(upload, "filename", None) or "",
                                    "content_type": getattr(upload, "content_type", None) or "",
                                    "data": raw,
                                }
                            else:
                                request.state.upload = None
                        else:
                            request.state.upload = None
                    except Exception as exc:
                        request.state.upload = None
                        request.state.upload_error = str(exc)
                else:
                    request.state.json_body = {}
                    request.state.upload = None
            else:
                request.state.json_body = {}
                request.state.upload = None

            method = request.method.upper()
            path = _normalize_path(request.url.path)
            key = f"{method} {path}"
            handler = _the_registry._routes.get(key)
            if handler is None:
                return json_error(
                    code="not_found",
                    message=f"No route for {method} {path}",
                    status=404,
                )
            return await run_in_threadpool(handler)
        finally:
            reset_request_context()

    return app


def _mount_media(app: FastAPI) -> None:
    from modules.user.upload_config import upload_root

    root = upload_root()
    os.makedirs(root, exist_ok=True)
    app.mount("/media", StaticFiles(directory=root), name="media")

    catalog_root = os.environ.get("CATALOG_MEDIA_ROOT", "/data/catalog-media").strip()
    if not catalog_root:
        catalog_root = "/data/catalog-media"
    os.makedirs(catalog_root, exist_ok=True)
    app.mount(
        "/catalog-media",
        StaticFiles(directory=catalog_root),
        name="catalog_media",
    )


def _normalize_path(path: str) -> str:
    if path == "":
        return "/"
    if path != "/" and path.endswith("/"):
        return path[:-1]
    return path


def _join_tier_path(tier_prefix: str, path: str) -> str:
    """Join tier prefix with a tier-relative path from module registration."""
    p = _normalize_path(path)
    if not tier_prefix:
        return p
    if p == "/":
        return tier_prefix
    return f"{tier_prefix}{p}"


class _RouteRegistry(ApplicationRouteSink):
    def __init__(self) -> None:
        self._routes: dict[str, Callable[[], Response]] = {}

    def clear(self) -> None:
        self._routes.clear()

    def _add(self, method: str, path: str, handler: Callable[[], Response]) -> None:
        key = f"{method.upper()} {_normalize_path(path)}"
        self._routes[key] = handler

    def _wrap_authuser(self, inner: Callable[[], Response]) -> Callable[[], Response]:
        return authuser_guard(inner)

    def _wrap_service(self, inner: Callable[[], Response]) -> Callable[[], Response]:
        return service_guard(inner)

    def public_get(self, path: str, handler: Callable[[], Response]) -> None:
        self._add("GET", path, handler)

    def public_post(self, path: str, handler: Callable[[], Response]) -> None:
        self._add("POST", path, handler)

    def public_put(self, path: str, handler: Callable[[], Response]) -> None:
        self._add("PUT", path, handler)

    def public_delete(self, path: str, handler: Callable[[], Response]) -> None:
        self._add("DELETE", path, handler)

    def authuser_get(self, path: str, handler: Callable[[], Response]) -> None:
        self._add(
            "GET",
            _join_tier_path(_PREFIX_AUTHUSER, path),
            self._wrap_authuser(handler),
        )

    def authuser_post(self, path: str, handler: Callable[[], Response]) -> None:
        self._add(
            "POST",
            _join_tier_path(_PREFIX_AUTHUSER, path),
            self._wrap_authuser(handler),
        )

    def authuser_put(self, path: str, handler: Callable[[], Response]) -> None:
        self._add(
            "PUT",
            _join_tier_path(_PREFIX_AUTHUSER, path),
            self._wrap_authuser(handler),
        )

    def authuser_delete(self, path: str, handler: Callable[[], Response]) -> None:
        self._add(
            "DELETE",
            _join_tier_path(_PREFIX_AUTHUSER, path),
            self._wrap_authuser(handler),
        )

    def service_get(self, path: str, handler: Callable[[], Response]) -> None:
        self._add(
            "GET",
            _join_tier_path(_PREFIX_SERVICE, path),
            self._wrap_service(handler),
        )

    def service_post(self, path: str, handler: Callable[[], Response]) -> None:
        self._add(
            "POST",
            _join_tier_path(_PREFIX_SERVICE, path),
            self._wrap_service(handler),
        )

    def service_put(self, path: str, handler: Callable[[], Response]) -> None:
        self._add(
            "PUT",
            _join_tier_path(_PREFIX_SERVICE, path),
            self._wrap_service(handler),
        )

    def service_delete(self, path: str, handler: Callable[[], Response]) -> None:
        self._add(
            "DELETE",
            _join_tier_path(_PREFIX_SERVICE, path),
            self._wrap_service(handler),
        )


_the_registry = _RouteRegistry()
application_routes: ApplicationRouteSink = _the_registry
