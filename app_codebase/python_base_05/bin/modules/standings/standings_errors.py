"""Standings module error codes."""

from core.errors.contracts.register_module_error_contract import ModuleErrorRegistrar
from core.errors.error_spec import ErrorSpec

NOT_FOUND = ErrorSpec(
    "standings/not_found",
    "Standings resource not found",
    http_status=404,
)
INVALID_QUERY = ErrorSpec(
    "standings/invalid_query",
    "Invalid standings query",
    http_status=400,
)


def register_standings_errors(registrar: ModuleErrorRegistrar) -> None:
    registrar.register_module(
        "standings",
        [
            NOT_FOUND,
            INVALID_QUERY,
        ],
    )
