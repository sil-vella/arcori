"""Declarative rules per notification (source, category, subtype)."""

from __future__ import annotations

from dataclasses import dataclass, field

from core.notifications.response_types import RESPONSE_TYPE_NAVIGATE, RESPONSE_TYPE_REPLY

DEFAULT_INTER_MODAL_DELAY_MS = 700


@dataclass(frozen=True)
class NotificationSubtypeSpec:
    source: str
    category: str
    subtype: str
    default_delivery: str | None = None
    allowed_screens: frozenset[str] = field(default_factory=frozenset)
    allowed_response_types: frozenset[str] = field(
        default_factory=lambda: frozenset({RESPONSE_TYPE_NAVIGATE, RESPONSE_TYPE_REPLY})
    )
    reply_option_keys: frozenset[str] | None = None
    modal_priority: int = 100
    mark_read_on_dismiss: bool = True
    inter_modal_delay_ms: int = DEFAULT_INTER_MODAL_DELAY_MS

    @property
    def key(self) -> tuple[str, str, str]:
        return (self.source.strip(), self.category.strip(), self.subtype.strip())
