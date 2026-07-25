"""Catalog module error codes."""

from core.errors.contracts.register_module_error_contract import ModuleErrorRegistrar
from core.errors.error_spec import ErrorSpec

NOT_FOUND = ErrorSpec(
    "catalog/not_found",
    "Catalog resource not found",
    http_status=404,
)
INVALID_QUERY = ErrorSpec(
    "catalog/invalid_query",
    "Invalid catalog query",
    http_status=400,
)
LOAD_FAILED = ErrorSpec(
    "catalog/load_failed",
    "Failed to load catalog data",
    http_status=500,
)


def register_catalog_errors(registrar: ModuleErrorRegistrar) -> None:
    registrar.register_module(
        "catalog",
        [
            NOT_FOUND,
            INVALID_QUERY,
            LOAD_FAILED,
        ],
    )
