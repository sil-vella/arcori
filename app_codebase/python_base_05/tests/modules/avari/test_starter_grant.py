"""Starter pack pick + grant."""

from __future__ import annotations

import random
import unittest
import uuid
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from modules.avari.mastery_economy import STARTER_INITIAL_MASTERY
from modules.avari.starter_grant import (
    STARTER_PACK_SIZE,
    grant_starter_pack,
    pick_starter_design_ids,
)


class StarterGrantTests(unittest.TestCase):
    def test_starter_initial_mastery_is_ten(self) -> None:
        self.assertEqual(STARTER_INITIAL_MASTERY, 10)
        self.assertEqual(STARTER_PACK_SIZE, 10)

    def test_pick_samples_without_replacement(self) -> None:
        pool = [f"D{i}" for i in range(20)]
        with patch(
            "modules.avari.starter_grant.circulating_playable_design_ids",
            return_value=pool,
        ):
            picked = pick_starter_design_ids(10, rng=random.Random(1))
        self.assertEqual(len(picked), 10)
        self.assertEqual(len(set(picked)), 10)
        self.assertTrue(set(picked) <= set(pool))

    def test_pool_is_genesis_and_pioneers_only(self) -> None:
        from modules.avari.starter_grant import circulating_playable_design_ids

        pool = circulating_playable_design_ids()
        self.assertTrue(pool)
        for iid in pool:
            self.assertTrue(
                "-SER001-" in iid or "-SER002-" in iid,
                msg=f"starter pool leaked non-Genesis/Pioneers id: {iid}",
            )
            self.assertNotIn("-SER003-", iid)

    @patch("modules.avari.avari_repository.ensure_slammer")
    @patch("modules.avari.avari_repository.ensure_mastery_row")
    @patch("modules.avari.avari_repository.ensure_design_access")
    @patch(
        "modules.avari.starter_grant.pick_starter_design_ids",
        return_value=["ANM-TIG-SER001-0001", "ANM-LIO-SER001-0003"],
    )
    def test_grant_sets_mastery_and_flag(
        self,
        _pick: MagicMock,
        grant_access: MagicMock,
        ensure_m: MagicMock,
        _slammer: MagicMock,
    ) -> None:
        ensure_m.return_value = SimpleNamespace(points=10)
        session = MagicMock()
        profile = SimpleNamespace(onboarding_starter_granted=False)
        uid = uuid.UUID("a0000000-0000-4000-8000-000000000099")
        out = grant_starter_pack(session, user_id=uid, profile=profile)
        self.assertEqual(out, ["ANM-TIG-SER001-0001", "ANM-LIO-SER001-0003"])
        self.assertTrue(profile.onboarding_starter_granted)
        self.assertEqual(grant_access.call_count, 2)
        for call in ensure_m.call_args_list:
            if "initial_points" in call.kwargs:
                self.assertEqual(call.kwargs["initial_points"], 10)


if __name__ == "__main__":
    unittest.main()
