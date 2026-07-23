"""Known notification screen names for server-side validation (mirrors Flutter registry)."""

from __future__ import annotations

_BUILTIN_SCREENS = frozenset(
    {
        "home",
        "notifications",
        "example_module",
        "sample",
        "account",
        "ws_demo",
    }
)

_extra_screens: set[str] = set()


def register_notification_screen(name: str) -> None:
    key = name.strip()
    if key:
        _extra_screens.add(key)


def reset_notification_screens() -> None:
    _extra_screens.clear()


def is_known_screen(name: str) -> bool:
    key = name.strip()
    return key in _BUILTIN_SCREENS or key in _extra_screens


def known_screens() -> frozenset[str]:
    return frozenset(_BUILTIN_SCREENS | _extra_screens)
