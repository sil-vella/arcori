"""Starter pack pick + grant."""

from __future__ import annotations

import random
import unittest
import uuid
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from modules.avari.mastery_economy import STARTER_INITIAL_MASTERY
from modules.avari.starter_grant import (
    STARTER_COMMON_COUNT,
    STARTER_PACK_SIZE,
    STARTER_SCARCE_COUNT,
    circulating_playable_designs,
    grant_starter_pack,
    pick_starter_design_ids,
)
from modules.catalog.catalog_service import get_design


class StarterGrantTests(unittest.TestCase):
    def test_starter_initial_mastery_is_ten(self) -> None:
        self.assertEqual(STARTER_INITIAL_MASTERY, 10)
        self.assertEqual(STARTER_PACK_SIZE, 10)
        self.assertEqual(STARTER_COMMON_COUNT, 9)
        self.assertEqual(STARTER_SCARCE_COUNT, 1)

    def test_pick_samples_without_replacement(self) -> None:
        pool = [(f"D{i}", 9.0 if i < 15 else 3.5) for i in range(20)]
        with patch(
            "modules.avari.starter_grant.circulating_playable_designs",
            return_value=pool,
        ):
            picked = pick_starter_design_ids(10, rng=random.Random(1))
        self.assertEqual(len(picked), 10)
        self.assertEqual(len(set(picked)), 10)
        self.assertTrue(set(picked) <= {iid for iid, _ in pool})

    def test_pick_bands_nine_common_one_scarce(self) -> None:
        pool = [(f"C{i}", 9.0) for i in range(20)] + [
            (f"S{i}", 3.5) for i in range(5)
        ]
        with patch(
            "modules.avari.starter_grant.circulating_playable_designs",
            return_value=pool,
        ):
            picked = pick_starter_design_ids(10, rng=random.Random(2))
        by_id = {iid: w for iid, w in pool}
        common = [iid for iid in picked if 8.0 <= by_id[iid] <= 10.0]
        scarce = [iid for iid in picked if 3.0 <= by_id[iid] <= 4.0]
        self.assertEqual(len(common), 9)
        self.assertEqual(len(scarce), 1)

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
            self.assertNotIn("-SER000-", iid)

    def test_live_catalog_bands_support_starter_pack(self) -> None:
        designs = circulating_playable_designs()
        common = [iid for iid, w in designs if 8.0 <= w <= 10.0]
        scarce = [iid for iid, w in designs if 3.0 <= w <= 4.0]
        self.assertGreaterEqual(len(common), STARTER_COMMON_COUNT)
        self.assertGreaterEqual(len(scarce), STARTER_SCARCE_COUNT)
        picked = pick_starter_design_ids(10, rng=random.Random(0))
        self.assertEqual(len(picked), 10)
        weights = []
        for iid in picked:
            design = get_design(iid)
            weights.append(float(design["selectionWeight"]))
        self.assertEqual(sum(1 for w in weights if 8.0 <= w <= 10.0), 9)
        self.assertEqual(sum(1 for w in weights if 3.0 <= w <= 4.0), 1)

    def test_creation_is_point_zero_one(self) -> None:
        for iid in ("LGT-TLT-SER000-0001", "DRK-TDK-SER000-0001"):
            design = get_design(iid)
            self.assertEqual(float(design["selectionWeight"]), 0.01)

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
