"""Notification module error codes."""

from core.errors.contracts.register_module_error_contract import ModuleErrorRegistrar
from core.errors.error_spec import ErrorSpec

INVALID_NOTIFICATION_TYPE = ErrorSpec(
    "notifications/invalid_type",
    "Notification type must be instant or inbox",
    http_status=400,
)
INVALID_REQUEST = ErrorSpec(
    "notifications/invalid_request",
    "Invalid notification request",
    http_status=400,
)
NOT_FOUND = ErrorSpec(
    "notifications/not_found",
    "Notification not found",
    http_status=404,
)
INVALID_RESPONSE_CONFIG = ErrorSpec(
    "notifications/invalid_response_config",
    "Invalid notification response configuration",
    http_status=400,
)
INVALID_RESPONSE = ErrorSpec(
    "notifications/invalid_response",
    "Invalid notification response option",
    http_status=400,
)
HANDLER_NOT_FOUND = ErrorSpec(
    "notifications/handler_not_found",
    "No handler registered for this notification response",
    http_status=404,
)
NOT_REPLY_TYPE = ErrorSpec(
    "notifications/not_reply_type",
    "Notification does not accept server replies",
    http_status=400,
)
UNKNOWN_SUBTYPE = ErrorSpec(
    "notifications/unknown_subtype",
    "Unknown notification category/subtype for source",
    http_status=400,
)
INVALID_CATEGORY = ErrorSpec(
    "notifications/invalid_category",
    "Notification category is required",
    http_status=400,
)


def register_notification_errors(registrar: ModuleErrorRegistrar) -> None:
    registrar.register_module(
        "notifications",
        [
            INVALID_NOTIFICATION_TYPE,
            INVALID_REQUEST,
            NOT_FOUND,
            INVALID_RESPONSE_CONFIG,
            INVALID_RESPONSE,
            HANDLER_NOT_FOUND,
            NOT_REPLY_TYPE,
            UNKNOWN_SUBTYPE,
            INVALID_CATEGORY,
        ],
    )
