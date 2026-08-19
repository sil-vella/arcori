"""Wire feature modules into the HTTP layer from ``createHttpHandler`` when you add routes."""

from core.errors.module_error_registry import module_error_registrar, reset_module_error_registry
from core.http.response.response import http_responses
from core.http.service.routes import application_routes
from core.ws.service.channel_registry import application_ws_sink
from modules.auth.auth_app import register_auth_routes
from modules.auth.auth_errors import register_auth_errors
from modules.avari.avari_app import register_avari_routes
from modules.avari.avari_errors import register_avari_errors
from modules.catalog.catalog_app import register_catalog_routes
from modules.catalog.catalog_errors import register_catalog_errors
from modules.example_module.example_app import register_example_module_routes
from modules.notifications.notification_app import register_notification_routes
from modules.notifications.notification_errors import register_notification_errors
from modules.ops.ops_app import register_ops_routes
from modules.ops.ops_errors import register_ops_errors
from modules.players.players_app import register_players_routes
from modules.players.players_errors import register_players_errors
from modules.presence.presence_app import register_presence_routes
from modules.presence.presence_errors import register_presence_errors
from modules.standings.standings_app import register_standings_routes
from modules.standings.standings_errors import register_standings_errors
from modules.contacts.contacts_app import register_contacts_routes
from modules.contacts.contacts_errors import register_contacts_errors
from modules.service.service_app import register_service_routes
from modules.user.user_app import register_user_routes
from modules.ws.demo_errors import register_demo_errors
from modules.ws.demo_ws_app import register_demo_ws_channels
from modules.friend_match_invite.friend_match_invite_app import (
    register_friend_match_invite_routes,
)
from modules.friend_match_invite.friend_match_invite_errors import (
    register_friend_match_invite_errors,
)
from modules.friend_match_invite.friend_match_invite_notifications import (
    register_friend_match_invite_notification_handlers,
    register_friend_match_invite_notification_subtypes,
)


def register_notification_reply_handlers() -> None:
    from core.notifications.register_builtin_subtypes import (
        register_builtin_notification_subtypes,
    )
    from core.notifications.subtype_registry import reset_notification_subtypes
    from modules.example_module.example_notifications import (
        register_example_notification_handlers,
    )

    reset_notification_subtypes()
    register_builtin_notification_subtypes()
    register_friend_match_invite_notification_subtypes()
    register_example_notification_handlers()
    register_friend_match_invite_notification_handlers()


def register_application_routes() -> None:
    register_user_routes(application_routes, http_responses)
    register_service_routes(application_routes, http_responses)
    register_example_module_routes(application_routes, http_responses)
    register_notification_routes(application_routes, http_responses)
    register_friend_match_invite_routes(application_routes, http_responses)
    register_contacts_routes(application_routes, http_responses)
    register_catalog_routes(application_routes, http_responses)
    register_players_routes(application_routes, http_responses)
    register_standings_routes(application_routes, http_responses)
    register_avari_routes(application_routes, http_responses)
    register_presence_routes(application_routes, http_responses)
    register_ops_routes(application_routes, http_responses)
    register_auth_routes(application_routes, http_responses)


def register_application_errors() -> None:
    reset_module_error_registry()
    register_auth_errors(module_error_registrar)
    register_demo_errors(module_error_registrar)
    register_notification_errors(module_error_registrar)
    register_catalog_errors(module_error_registrar)
    register_friend_match_invite_errors(module_error_registrar)
    register_contacts_errors(module_error_registrar)
    register_players_errors(module_error_registrar)
    register_standings_errors(module_error_registrar)
    register_avari_errors(module_error_registrar)
    register_presence_errors(module_error_registrar)
    register_ops_errors(module_error_registrar)


def register_application_channels() -> None:
    register_demo_ws_channels(application_ws_sink)
