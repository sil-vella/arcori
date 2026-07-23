"""Tests for dev_logger customlog and DUTCH_DEV_LOG gate."""

from __future__ import annotations

import pytest

from core.utils.dev_logger import customlog, is_dutch_dev_log_truthy


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        (None, False),
        ("", False),
        ("0", False),
        ("1", True),
        ("true", True),
        ("TRUE", True),
        ("yes", True),
        ("YES", True),
    ],
)
def test_is_dutch_dev_log_truthy(raw: str | None, expected: bool) -> None:
    assert is_dutch_dev_log_truthy(raw) is expected


def test_customlog_silent_when_off(monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    monkeypatch.delenv("DUTCH_DEV_LOG", raising=False)
    customlog("hidden")
    captured = capsys.readouterr()
    assert captured.err == ""


def test_customlog_emits_dev_prefix_when_on(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    monkeypatch.setenv("DUTCH_DEV_LOG", "1")
    customlog("hello")
    captured = capsys.readouterr()
    assert captured.err.strip() == "[dev] hello"
