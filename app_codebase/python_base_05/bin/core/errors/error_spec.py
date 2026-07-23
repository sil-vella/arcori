"""ErrorSpec — metadata for core and module error codes."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class ErrorSpec:
    code: str
    message: str
    http_status: int
    fatal_ws: bool = False

    def is_module_code(self) -> bool:
        return "/" in self.code
