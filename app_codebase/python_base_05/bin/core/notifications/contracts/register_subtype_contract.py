"""Module-facing contract for registering notification subtype specs."""

from __future__ import annotations

from typing import Protocol

from core.notifications.subtype_spec import NotificationSubtypeSpec


class NotificationSubtypeRegistrar(Protocol):
    def register_subtype(self, spec: NotificationSubtypeSpec) -> None: ...
