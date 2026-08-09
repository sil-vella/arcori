"""Players AI sample service unit tests."""

from __future__ import annotations

import uuid
import unittest
from unittest.mock import MagicMock, patch

from core.errors.app_error import AppError
from modules.players.players_service import sample_ai_players


class PlayersServiceTests(unittest.TestCase):
    @patch("modules.players.players_service.session_scope")
    def test_sample_ai_players(self, scope: MagicMock) -> None:
        session = MagicMock()
        ctx = MagicMock()
        ctx.__enter__.return_value = session
        ctx.__exit__.return_value = False
        scope.return_value = ctx

        uid1 = uuid.uuid4()
        uid2 = uuid.uuid4()
        session.execute.return_value.all.return_value = [
            (uid1, "ai_0001", "Aric"),
            (uid2, "ai_0002", "Blair"),
        ]

        out = sample_ai_players(count=2)
        self.assertEqual(len(out["players"]), 2)
        self.assertEqual(out["players"][0]["userId"], str(uid1))

    @patch("modules.players.players_service.session_scope")
    def test_sample_ai_unavailable(self, scope: MagicMock) -> None:
        session = MagicMock()
        ctx = MagicMock()
        ctx.__enter__.return_value = session
        ctx.__exit__.return_value = False
        scope.return_value = ctx
        session.execute.return_value.all.return_value = []

        with self.assertRaises(AppError) as ctx_err:
            sample_ai_players(count=2)
        self.assertEqual(ctx_err.exception.spec.code, "players/ai_unavailable")
