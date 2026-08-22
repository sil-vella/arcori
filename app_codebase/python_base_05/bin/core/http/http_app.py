"""Build the FastAPI application the process will serve.

Call order matters: we clear any previous route list so tests and restarts do not stack duplicate
routes; then ``register_application_routes`` (from ``modules.module_registry``) runs so each
feature registers its endpoints on ``application_routes``; finally we return the FastAPI app built
from that list. The server should call ``createHttpHandler`` as the one place to obtain that app.
"""

from fastapi import FastAPI

from core.auth.auth_config import require_secrets_for_production
from core.errors.module_error_registry import reset_module_error_registry
from core.http.service.routes import build_application_handler, reset_route_registry
from core.state.state_registry import inbox_broadcaster
from core.utils.prod_runtime import configure_production
from core.ws.ws_app import configure_websockets
from modules.module_registry import (
    register_application_errors,
    register_application_routes,
    register_notification_reply_handlers,
)


def createHttpHandler() -> FastAPI:
    require_secrets_for_production()
    reset_module_error_registry()
    register_application_errors()
    register_notification_reply_handlers()
    reset_route_registry()
    register_application_routes()
    app = build_application_handler()
    configure_production(app)
    configure_websockets(app)
    inbox_broadcaster.start_cross_worker_listener()
    return app
