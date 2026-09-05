"""Owned slammer verify for match seating."""

from __future__ import annotations

import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from core.errors.app_error import AppError
from modules.avari.avari_service import verify_slammers_for_seats


def _row(design_id: str, *, permanent: bool = False) -> SimpleNamespace:
    return SimpleNamespace(design_id=design_id, permanent=permanent)


class VerifySlammersTests(unittest.TestCase):
    def test_owned_requested_id(self) -> None:
        rows = [_row("SLM-STR-GEN001-0001", permanent=True)]
        with patch(
            "modules.avari.avari_repository.list_slammers",
            return_value=rows,
        ), patch("modules.avari.avari_service.session_scope") as scope:
            session = MagicMock()
            ctx = MagicMock()
            ctx.__enter__.return_value = session
            ctx.__exit__.return_value = False
            scope.return_value = ctx
            out = verify_slammers_for_seats(
                [
                    {
                        "userId": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
                        "slammerId": "SLM-STR-GEN001-0001",
                    }
                ]
            )
        self.assertEqual(out["assignments"][0]["slammerId"], "SLM-STR-GEN001-0001")
        self.assertEqual(out["assignments"][0]["source"], "owned")

    def test_not_owned_falls_back_to_permanent(self) -> None:
        rows = [
            _row("SLM-STR-GEN001-0001", permanent=True),
            _row("SLM-TTN-GEN001-0002", permanent=False),
        ]
        with patch(
            "modules.avari.avari_repository.list_slammers",
            return_value=rows,
        ), patch("modules.avari.avari_service.session_scope") as scope:
            session = MagicMock()
            ctx = MagicMock()
            ctx.__enter__.return_value = session
            ctx.__exit__.return_value = False
            scope.return_value = ctx
            out = verify_slammers_for_seats(
                [
                    {
                        "userId": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
                        "slammerId": "SLM-FAKE-NOT-OWNED",
                    }
                ]
            )
        self.assertEqual(out["assignments"][0]["slammerId"], "SLM-STR-GEN001-0001")
        self.assertEqual(out["assignments"][0]["source"], "fallback")
        self.assertEqual(out["assignments"][0]["reason"], "not_owned")

    def test_empty_inventory(self) -> None:
        with patch(
            "modules.avari.avari_repository.list_slammers",
            return_value=[],
        ), patch("modules.avari.avari_service.session_scope") as scope:
            session = MagicMock()
            ctx = MagicMock()
            ctx.__enter__.return_value = session
            ctx.__exit__.return_value = False
            scope.return_value = ctx
            out = verify_slammers_for_seats(
                [{"userId": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"}]
            )
        self.assertEqual(out["assignments"][0]["slammerId"], "")
        self.assertEqual(out["assignments"][0]["source"], "empty")

    def test_seats_required(self) -> None:
        with self.assertRaises(AppError) as err:
            verify_slammers_for_seats([])
        self.assertEqual(err.exception.code, "avari/invalid_query")


if __name__ == "__main__":
    unittest.main()
