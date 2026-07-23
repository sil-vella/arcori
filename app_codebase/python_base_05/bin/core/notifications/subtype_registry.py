"""Registry of notification subtype specs — modules register at bootstrap."""

from __future__ import annotations

from core.notifications.subtype_spec import DEFAULT_INTER_MODAL_DELAY_MS, NotificationSubtypeSpec

_specs: dict[tuple[str, str, str], NotificationSubtypeSpec] = {}


def reset_notification_subtypes() -> None:
    _specs.clear()


def register_notification_subtype(spec: NotificationSubtypeSpec) -> None:
    key = spec.key
    if not all(key):
        raise ValueError("subtype spec requires source, category, and subtype")
    _specs[key] = spec


def lookup_subtype_spec(
    *,
    source: str,
    category: str | None,
    subtype: str | None,
) -> NotificationSubtypeSpec | None:
    if not category or not subtype:
        return None
    return _specs.get((source.strip(), category.strip(), subtype.strip()))


def require_subtype_spec(
    *,
    source: str,
    category: str,
    subtype: str,
) -> NotificationSubtypeSpec:
    from core.errors.app_error import AppError
    from modules.notifications.notification_errors import UNKNOWN_SUBTYPE

    spec = lookup_subtype_spec(source=source, category=category, subtype=subtype)
    if spec is None:
        raise AppError(UNKNOWN_SUBTYPE)
    return spec


def default_subtype_spec(
    *,
    source: str,
    category: str | None = None,
    subtype: str | None = None,
) -> NotificationSubtypeSpec:
    """Permissive fallback for legacy rows missing registry entries."""
    return NotificationSubtypeSpec(
        source=source.strip() or "unknown",
        category=(category or "legacy").strip(),
        subtype=(subtype or "legacy").strip(),
        allowed_screens=frozenset(),
        inter_modal_delay_ms=DEFAULT_INTER_MODAL_DELAY_MS,
    )
