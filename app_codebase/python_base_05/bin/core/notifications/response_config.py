"""Parse and validate declarative notification response config in data.response."""

from __future__ import annotations

import re
from typing import Any

from core.errors.app_error import AppError
from core.notifications.response_types import (
    MAX_NAVIGATE_BUTTONS,
    MAX_REPLY_OPTIONS,
    RESPONSE_TYPE_NAVIGATE,
    RESPONSE_TYPE_REPLY,
    RESPONSE_TYPES,
)
from core.notifications.screen_names import is_known_screen
from core.notifications.subtype_registry import default_subtype_spec, lookup_subtype_spec
from core.notifications.subtype_spec import NotificationSubtypeSpec

_OPTION_KEY_RE = re.compile(r"^[a-z][a-z0-9_]{0,31}$")

_INVALID_RESPONSE_CONFIG = None  # set after notification_errors import cycle


def _invalid_config(message: str) -> AppError:
    from modules.notifications.notification_errors import INVALID_RESPONSE_CONFIG

    return AppError(INVALID_RESPONSE_CONFIG, message=message)


def extract_response_config(data: dict[str, Any] | None) -> dict[str, Any] | None:
    if not isinstance(data, dict):
        return None
    response = data.get("response")
    if not isinstance(response, dict) or not response:
        return None
    return response


def validate_response_config(
    response: dict[str, Any],
    *,
    subtype_spec: NotificationSubtypeSpec | None = None,
) -> dict[str, Any]:
    """Return normalized response config or raise AppError."""
    if not isinstance(response, dict):
        raise _invalid_config("response must be an object")

    response_type = str(response.get("type", "")).strip().lower()
    if response_type not in RESPONSE_TYPES:
        raise _invalid_config("response.type must be navigate or reply")

    if subtype_spec is not None and response_type not in subtype_spec.allowed_response_types:
        raise _invalid_config(f"response.type {response_type} is not allowed for this subtype")

    if response_type == RESPONSE_TYPE_NAVIGATE:
        return _validate_navigate(response, subtype_spec=subtype_spec)
    return _validate_reply(response, subtype_spec=subtype_spec)


def validate_data_response(
    data: dict[str, Any] | None,
    *,
    source: str | None = None,
    category: str | None = None,
    subtype: str | None = None,
) -> dict[str, Any] | None:
    """Validate data.response when present; return normalized data dict."""
    if data is None:
        return {}
    if not isinstance(data, dict):
        raise _invalid_config("data must be an object")
    response = extract_response_config(data)
    if response is None:
        return dict(data)
    subtype_spec = None
    if source:
        subtype_spec = lookup_subtype_spec(
            source=source,
            category=category,
            subtype=subtype,
        ) or default_subtype_spec(source=source, category=category, subtype=subtype)
    normalized = validate_response_config(response, subtype_spec=subtype_spec)
    merged = dict(data)
    merged["response"] = normalized
    return merged


def _validate_navigate(
    response: dict[str, Any],
    *,
    subtype_spec: NotificationSubtypeSpec | None = None,
) -> dict[str, Any]:
    buttons_raw = response.get("buttons")
    if not isinstance(buttons_raw, list) or not buttons_raw:
        raise _invalid_config("navigate response requires a non-empty buttons array")

    if len(buttons_raw) > MAX_NAVIGATE_BUTTONS:
        raise _invalid_config(f"navigate allows at most {MAX_NAVIGATE_BUTTONS} buttons")

    buttons: list[dict[str, str]] = []
    for index, item in enumerate(buttons_raw):
        if not isinstance(item, dict):
            raise _invalid_config(f"buttons[{index}] must be an object")
        label = str(item.get("label", "")).strip()
        if not label:
            raise _invalid_config(f"buttons[{index}].label is required")
        screen = str(item.get("screen", "")).strip()
        to_path = str(item.get("to_path", "")).strip()
        if bool(screen) == bool(to_path):
            raise _invalid_config(
                f"buttons[{index}] requires exactly one of screen or to_path"
            )
        if screen and not is_known_screen(screen):
            raise _invalid_config(f"buttons[{index}].screen is not registered: {screen}")
        if (
            screen
            and subtype_spec is not None
            and subtype_spec.allowed_screens
            and screen not in subtype_spec.allowed_screens
        ):
            raise _invalid_config(
                f"buttons[{index}].screen is not allowed for this subtype: {screen}"
            )
        entry: dict[str, str] = {"label": label}
        if screen:
            entry["screen"] = screen
        else:
            entry["to_path"] = to_path
        buttons.append(entry)

    mark_read = response.get("mark_read_on_action", True)
    return {
        "type": RESPONSE_TYPE_NAVIGATE,
        "buttons": buttons,
        "mark_read_on_action": bool(mark_read),
    }


def _validate_reply(
    response: dict[str, Any],
    *,
    subtype_spec: NotificationSubtypeSpec | None = None,
) -> dict[str, Any]:
    options_raw = response.get("options")
    if not isinstance(options_raw, list) or not options_raw:
        raise _invalid_config("reply response requires a non-empty options array")

    if len(options_raw) > MAX_REPLY_OPTIONS:
        raise _invalid_config(f"reply allows at most {MAX_REPLY_OPTIONS} options")

    options: list[dict[str, str]] = []
    seen_keys: set[str] = set()
    for index, item in enumerate(options_raw):
        if not isinstance(item, dict):
            raise _invalid_config(f"options[{index}] must be an object")
        key = str(item.get("key", "")).strip().lower()
        label = str(item.get("label", "")).strip()
        if not key or not _OPTION_KEY_RE.match(key):
            raise _invalid_config(f"options[{index}].key must be snake_case")
        if key in seen_keys:
            raise _invalid_config(f"duplicate option key: {key}")
        if not label:
            raise _invalid_config(f"options[{index}].label is required")
        seen_keys.add(key)
        options.append({"key": key, "label": label})

    if subtype_spec is not None and subtype_spec.reply_option_keys is not None:
        if seen_keys != subtype_spec.reply_option_keys:
            raise _invalid_config("reply option keys do not match subtype spec")

    mark_read = response.get("mark_read_on_success", True)
    return {
        "type": RESPONSE_TYPE_REPLY,
        "options": options,
        "mark_read_on_success": bool(mark_read),
    }


def response_type_of_data(data: dict[str, Any] | None) -> str | None:
    response = extract_response_config(data)
    if response is None:
        return None
    return str(response.get("type", "")).strip().lower() or None
