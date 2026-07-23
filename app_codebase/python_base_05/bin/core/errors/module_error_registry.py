"""Runtime registry for module-owned namespaced error codes."""

from __future__ import annotations

from core.errors.contracts.register_module_error_contract import ModuleErrorRegistrar
from core.errors.error_codes import CORE_CODES
from core.errors.error_spec import ErrorSpec


class _ModuleErrorRegistry(ModuleErrorRegistrar):
    def __init__(self) -> None:
        self._specs: dict[str, ErrorSpec] = {}

    def clear(self) -> None:
        self._specs.clear()

    def register_module(self, module_name: str, specs: Iterable[ErrorSpec]) -> None:
        prefix = f"{module_name}/"
        for spec in specs:
            if spec.code in CORE_CODES:
                raise ValueError(f"Module code collides with core catalog: {spec.code}")
            if not spec.is_module_code():
                raise ValueError(
                    f"Module error code must be namespaced (module/reason): {spec.code}"
                )
            if not spec.code.startswith(prefix):
                raise ValueError(
                    f"Module {module_name!r} code must start with {prefix!r}: {spec.code}"
                )
            if spec.code in self._specs:
                raise ValueError(f"Duplicate module error code: {spec.code}")
            self._specs[spec.code] = spec

    def lookup(self, code: str) -> ErrorSpec | None:
        return self._specs.get(code)


module_error_registrar: ModuleErrorRegistrar = _ModuleErrorRegistry()


def reset_module_error_registry() -> None:
    _registry = module_error_registrar
    if isinstance(_registry, _ModuleErrorRegistry):
        _registry.clear()


def lookup_module_error(code: str) -> ErrorSpec | None:
    _registry = module_error_registrar
    if isinstance(_registry, _ModuleErrorRegistry):
        return _registry.lookup(code)
    return None
