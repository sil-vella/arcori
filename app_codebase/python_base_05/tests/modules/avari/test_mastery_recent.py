"""Mastery recent change log helpers (no DB)."""

from __future__ import annotations

from modules.avari.avari_repository import _MASTERY_LOG_KEEP


def test_mastery_log_keep_cap() -> None:
    assert _MASTERY_LOG_KEEP == 20
