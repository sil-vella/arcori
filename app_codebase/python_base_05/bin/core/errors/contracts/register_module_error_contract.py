"""Let feature modules register domain error codes without touching the core catalog."""

from __future__ import annotations

from typing import Iterable, Protocol

from core.errors.error_spec import ErrorSpec


class ModuleErrorRegistrar(Protocol):
    def register_module(self, module_name: str, specs: Iterable[ErrorSpec]) -> None: ...
