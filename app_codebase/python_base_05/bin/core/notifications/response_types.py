"""Core notification response type constants."""

from __future__ import annotations

RESPONSE_TYPE_NAVIGATE = "navigate"
RESPONSE_TYPE_REPLY = "reply"

RESPONSE_TYPES = frozenset({RESPONSE_TYPE_NAVIGATE, RESPONSE_TYPE_REPLY})

MAX_NAVIGATE_BUTTONS = 3
MAX_REPLY_OPTIONS = 5
