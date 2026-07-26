"""Avari module error codes."""

from core.errors.contracts.register_module_error_contract import ModuleErrorRegistrar
from core.errors.error_spec import ErrorSpec

NOT_FOUND = ErrorSpec(
    "avari/not_found",
    "Avari profile not found",
    http_status=404,
)
INVALID_QUERY = ErrorSpec(
    "avari/invalid_query",
    "Invalid avari query",
    http_status=400,
)


def register_avari_errors(registrar: ModuleErrorRegistrar) -> None:
    registrar.register_module(
        "avari",
        [
            NOT_FOUND,
            INVALID_QUERY,
        ],
    )
