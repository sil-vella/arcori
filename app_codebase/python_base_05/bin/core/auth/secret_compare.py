"""Constant-time comparison for shared secrets."""

from __future__ import annotations

import hmac


def secrets_equal(provided: str, expected: str) -> bool:
    if not expected:
        return False
    return hmac.compare_digest(provided.encode("utf-8"), expected.encode("utf-8"))
