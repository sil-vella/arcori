"""Contacts module errors (username search + mutual contacts)."""

from __future__ import annotations

from core.errors.contracts.register_module_error_contract import ModuleErrorRegistrar
from core.errors.error_spec import ErrorSpec


INVALID_REQUEST = ErrorSpec(
    "contacts/invalid_request",
    "Invalid contacts request",
    http_status=400,
)

NOT_FOUND = ErrorSpec(
    "contacts/not_found",
    "User not found",
    http_status=404,
)

FORBIDDEN = ErrorSpec(
    "contacts/forbidden",
    "Action is not allowed",
    http_status=403,
)

UNAUTHORIZED = ErrorSpec(
    "contacts/unauthorized",
    "Unauthorized",
    http_status=401,
)


def register_contacts_errors(registrar: ModuleErrorRegistrar) -> None:
    registrar.register_module("contacts", [INVALID_REQUEST, NOT_FOUND, FORBIDDEN, UNAUTHORIZED])

