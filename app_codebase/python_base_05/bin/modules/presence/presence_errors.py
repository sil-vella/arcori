"""Presence module error codes."""

from core.errors.contracts.register_module_error_contract import ModuleErrorRegistrar
from core.errors.error_spec import ErrorSpec

INVALID_REQUEST = ErrorSpec(
    "presence/invalid_request",
    "Invalid presence request",
    http_status=400,
)


def register_presence_errors(registrar: ModuleErrorRegistrar) -> None:
    registrar.register_module("presence", [INVALID_REQUEST])
