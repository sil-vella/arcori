"""Developer-facing log helper — gated by DUTCH_DEV_LOG, emits [dev] prefix on stderr."""

from __future__ import annotations

import os
import sys

_TRUTHY = frozenset({"1", "true", "yes"})


def is_dutch_dev_log_truthy(raw: str | None) -> bool:
    """Return whether a DUTCH_DEV_LOG env value is considered on."""
    return (raw or "").strip().lower() in _TRUTHY


def _dutch_dev_log_enabled() -> bool:
    return is_dutch_dev_log_truthy(os.environ.get("DUTCH_DEV_LOG"))


def customlog(message: str) -> None:
    """Emit a dev-only line when DUTCH_DEV_LOG is truthy."""
    if not _dutch_dev_log_enabled():
        return
    print(f"[dev] {message}", file=sys.stderr, flush=True)
