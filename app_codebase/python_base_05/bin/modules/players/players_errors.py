"""Players module errors (service AI sample)."""

from __future__ import annotations

from core.errors.contracts.register_module_error_contract import ModuleErrorRegistrar
from core.errors.error_spec import ErrorSpec

INVALID_REQUEST = ErrorSpec("players/invalid_request", "Invalid players request", 400)
AI_UNAVAILABLE = ErrorSpec(
    "players/ai_unavailable",
    "Not enough AI players available",
    503,
)


def register_players_errors(registrar: ModuleErrorRegistrar) -> None:
    registrar.register_module("players", [INVALID_REQUEST, AI_UNAVAILABLE])
