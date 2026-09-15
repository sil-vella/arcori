"""Achievements module error codes."""

from core.errors.contracts.register_module_error_contract import ModuleErrorRegistrar
from core.errors.error_spec import ErrorSpec

INVALID_CATALOG = ErrorSpec(
    "achievements/invalid_catalog",
    "Invalid achievements catalog",
    http_status=500,
)
INVALID_QUERY = ErrorSpec(
    "achievements/invalid_query",
    "Invalid achievements query",
    http_status=400,
)
UNKNOWN_TYPE = ErrorSpec(
    "achievements/unknown_type",
    "Unknown achievement type",
    http_status=400,
)


def register_achievements_errors(registrar: ModuleErrorRegistrar) -> None:
    registrar.register_module(
        "achievements",
        [
            INVALID_CATALOG,
            INVALID_QUERY,
            UNKNOWN_TYPE,
        ],
    )
