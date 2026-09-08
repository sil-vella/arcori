"""claim_kin validation and insert path (mocked DB / IO)."""

from __future__ import annotations

import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from core.errors.app_error import AppError
from modules.avari.avari_errors import (
    INVALID_KIN_COLOR,
    INVALID_KIN_REGION,
    KIN_ALREADY_CLAIMED,
)
from modules.avari.avari_service import claim_kin


class ClaimKinTests(unittest.TestCase):
    def setUp(self) -> None:
        self.user_id = "a0000000-0000-4000-8000-000000000099"
        self.profile = {
            "user_id": self.user_id,
            "username": "claimtest",
            "email": "claim@test.com",
            "account_type": "Regular",
        }
        self.body = {
            "kinSerial": "KIN-BRZ-GEN001-0001",
            "typeSerial": "KTYPE-0001",
            "chosenName": "Bronze",
            "regionCode": "EVG",
            "color": "#C6A15B",
            "applied": [],
            "lottie": {"v": "5.7.4", "layers": []},
        }

    @patch("modules.avari.avari_service._write_kin_media")
    @patch("modules.avari.avari_service.session_scope")
    @patch("modules.avari.avari_service.get_user_profile")
    def test_rejects_rby(
        self, get_profile: MagicMock, scope: MagicMock, write_media: MagicMock
    ) -> None:
        get_profile.return_value = self.profile
        body = dict(self.body)
        body["regionCode"] = "RBY"
        with self.assertRaises(AppError) as ctx:
            claim_kin(self.user_id, body)
        self.assertEqual(ctx.exception.code, INVALID_KIN_REGION.code)
        write_media.assert_not_called()

    @patch("modules.avari.avari_service._write_kin_media")
    @patch("modules.avari.avari_service.session_scope")
    @patch("modules.avari.avari_service.get_user_profile")
    def test_rejects_bad_color(
        self, get_profile: MagicMock, scope: MagicMock, write_media: MagicMock
    ) -> None:
        get_profile.return_value = self.profile
        body = dict(self.body)
        body["color"] = "#FFFFFF"
        with self.assertRaises(AppError) as ctx:
            claim_kin(self.user_id, body)
        self.assertEqual(ctx.exception.code, INVALID_KIN_COLOR.code)

    @patch("modules.avari.avari_service._write_kin_media")
    @patch("modules.avari.avari_service.session_scope")
    @patch("modules.avari.avari_service.get_user_profile")
    def test_rejects_second_claim(
        self, get_profile: MagicMock, scope: MagicMock, write_media: MagicMock
    ) -> None:
        get_profile.return_value = self.profile
        session = MagicMock()
        ctx = MagicMock()
        ctx.__enter__.return_value = session
        ctx.__exit__.return_value = False
        scope.return_value = ctx

        with patch(
            "modules.avari.avari_repository.find_player_kin",
            return_value=SimpleNamespace(genesis_design_id="already"),
        ):
            with self.assertRaises(AppError) as err:
                claim_kin(self.user_id, self.body)
        self.assertEqual(err.exception.code, KIN_ALREADY_CLAIMED.code)

    @patch("modules.avari.avari_service._write_kin_media")
    @patch("modules.avari.avari_service.session_scope")
    @patch("modules.avari.avari_service.get_user_profile")
    def test_happy_path(
        self, get_profile: MagicMock, scope: MagicMock, write_media: MagicMock
    ) -> None:
        get_profile.return_value = self.profile
        session = MagicMock()
        ctx = MagicMock()
        ctx.__enter__.return_value = session
        ctx.__exit__.return_value = False
        scope.return_value = ctx

        avari = SimpleNamespace(
            onboarding_kin_chosen=False,
            onboarding_genesis_created=False,
        )

        with patch(
            "modules.avari.avari_repository.find_player_kin", return_value=None
        ), patch(
            "modules.avari.avari_repository.ensure_avari_profile",
            return_value=avari,
        ), patch(
            "modules.avari.avari_repository.count_player_kin", return_value=0
        ), patch(
            "modules.avari.avari_repository.serialize_kin",
            return_value={
                "chosenName": "Bronze",
                "genesisDesignId": "KIN-X",
                "color": "#C6A15B",
            },
        ):
            result = claim_kin(self.user_id, self.body)

        self.assertIn("kin", result)
        self.assertTrue(avari.onboarding_kin_chosen)
        self.assertTrue(avari.onboarding_genesis_created)
        session.add.assert_called_once()
        write_media.assert_called_once()
        added = session.add.call_args[0][0]
        self.assertEqual(added.subtheme, "Guardians")
        self.assertEqual(added.catalog_design["color"], "#C6A15B")
        self.assertEqual(
            frozenset(added.catalog_design.keys()),
            __import__(
                "modules.avari.kin_genesis", fromlist=["REGULAR_ARCORI_DESIGN_KEYS"]
            ).REGULAR_ARCORI_DESIGN_KEYS,
        )
        self.assertIn("designRelativePath", added.customization)


if __name__ == "__main__":
    unittest.main()
