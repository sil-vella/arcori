"""Special events module error codes."""

from core.errors.contracts.register_module_error_contract import ModuleErrorRegistrar
from core.errors.error_spec import ErrorSpec

INVALID_QUERY = ErrorSpec(
    "special_events/invalid_query",
    "Invalid special events query",
    http_status=400,
)
NOT_FOUND = ErrorSpec(
    "special_events/not_found",
    "Special event not found",
    http_status=404,
)
NOT_ELIGIBLE = ErrorSpec(
    "special_events/not_eligible",
    "Not eligible for this special event",
    http_status=400,
)


def register_special_events_errors(registrar: ModuleErrorRegistrar) -> None:
    registrar.register_module(
        "special_events",
        [
            INVALID_QUERY,
            NOT_FOUND,
            NOT_ELIGIBLE,
        ],
    )
