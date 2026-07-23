"""Ops module error codes."""

from __future__ import annotations

from core.errors.contracts.register_module_error_contract import ModuleErrorRegistrar
from core.errors.error_spec import ErrorSpec

DRAIN_MODE = ErrorSpec(
    "ops/drain_mode",
    "Server is in drain / maintenance mode",
    http_status=503,
)


def register_ops_errors(registrar: ModuleErrorRegistrar) -> None:
    registrar.register_module("ops", [DRAIN_MODE])
