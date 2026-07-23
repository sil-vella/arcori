"""Module-owned WebSocket demo error codes."""

from core.errors.contracts.register_module_error_contract import ModuleErrorRegistrar
from core.errors.error_spec import ErrorSpec

DEMO_ROOM_NOT_IMPLEMENTED = ErrorSpec(
    "ws/demo_room/not_implemented",
    "Room subscribe not implemented",
    http_status=501,
)


def register_demo_errors(registrar: ModuleErrorRegistrar) -> None:
    registrar.register_module("ws", [DEMO_ROOM_NOT_IMPLEMENTED])
