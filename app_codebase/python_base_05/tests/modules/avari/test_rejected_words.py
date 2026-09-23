"""Tests for player/Kin display-name rejected-words moderation."""

from __future__ import annotations

import unittest
from unittest.mock import MagicMock, patch

from core.errors.app_error import AppError
from modules.avari.avari_errors import REJECTED_KIN_NAME
from modules.avari.avari_service import claim_kin
from modules.avari.rejected_words import (
    REJECTED_NAME_USER_MESSAGE,
    is_rejected_kin_name,
    is_rejected_player_name,
    normalize_name_for_moderation,
)
from modules.auth.auth_service import AuthServiceError, register


class RejectedWordsMatcherTests(unittest.TestCase):
    def test_clear_names_pass(self) -> None:
        for name in ("Silver", "Luna", "Antler Lace", "María", "Jean-Luc"):
            self.assertFalse(is_rejected_player_name(name), name)
            self.assertFalse(is_rejected_kin_name(name), name)

    def test_english_token_rejected(self) -> None:
        self.assertTrue(is_rejected_player_name("shit"))
        self.assertTrue(is_rejected_player_name("Big Shit"))
        self.assertTrue(is_rejected_player_name("SHIT"))

    def test_spanish_token_rejected(self) -> None:
        self.assertTrue(is_rejected_player_name("mierda"))
        self.assertTrue(is_rejected_player_name("hijo de puta"))

    def test_french_token_rejected(self) -> None:
        self.assertTrue(is_rejected_player_name("putain"))
        self.assertTrue(is_rejected_player_name("ta mère"))

    def test_german_token_rejected(self) -> None:
        self.assertTrue(is_rejected_player_name("scheiße"))
        self.assertTrue(is_rejected_player_name("Arschloch"))

    def test_portuguese_token_rejected(self) -> None:
        self.assertTrue(is_rejected_player_name("porra"))
        self.assertTrue(is_rejected_player_name("filho da puta"))

    def test_punctuation_and_case_variants(self) -> None:
        self.assertTrue(is_rejected_player_name("Sh!t"))
        self.assertTrue(is_rejected_player_name("f.u.c.k"))
        # Punctuation splits letters into separate tokens after normalize.
        self.assertEqual(normalize_name_for_moderation("Sh!t"), "sh t")

    def test_compound_username_rejected(self) -> None:
        self.assertTrue(is_rejected_player_name("shitlord"))

    def test_safe_substring_not_rejected(self) -> None:
        # Short banned stems (len < 4) must not trip inside longer words.
        self.assertFalse(is_rejected_player_name("assassin"))
        self.assertFalse(is_rejected_player_name("classical"))


class RejectedKinClaimTests(unittest.TestCase):
    @patch("modules.avari.avari_service._write_kin_media")
    @patch("modules.avari.avari_service.session_scope")
    @patch("modules.avari.avari_service.get_user_profile")
    def test_claim_rejects_banned_name(
        self, get_profile: MagicMock, scope: MagicMock, write_media: MagicMock
    ) -> None:
        get_profile.return_value = {
            "user_id": "a0000000-0000-4000-8000-000000000099",
            "username": "claimtest",
        }
        body = {
            "kinSerial": "KIN-BRZ-SER001-0001",
            "typeSerial": "KTYPE-0001",
            "chosenName": "shit",
            "regionCode": "EVG",
            "color": "#C6A15B",
        }
        with self.assertRaises(AppError) as ctx:
            claim_kin("a0000000-0000-4000-8000-000000000099", body)
        self.assertEqual(ctx.exception.code, REJECTED_KIN_NAME.code)
        write_media.assert_not_called()


class RejectedUsernameAuthTests(unittest.TestCase):
    @patch("modules.auth.auth_service.enforce_auth_identity_rate_limit")
    def test_register_rejects_banned_username(self, _rate: MagicMock) -> None:
        with self.assertRaises(AuthServiceError) as ctx:
            register(
                username="shitlord",
                email="ok@example.com",
                password="password123",
                is_guest=False,
            )
        self.assertEqual(ctx.exception.code, "rejected_username")
        self.assertEqual(ctx.exception.message, REJECTED_NAME_USER_MESSAGE)


if __name__ == "__main__":
    unittest.main()
