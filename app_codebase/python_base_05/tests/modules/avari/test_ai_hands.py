"""AI hand pick: two of three users, stable, one of the shop hands."""

from __future__ import annotations

import uuid

from modules.avari.ai_hands import assigned_hand_id

HANDS = [
    "ARC-HND-CLG-SER008-GEN001-0001",
    "ARC-HND-CPR-SER008-GEN001-0002",
    "ARC-HND-LCY-SER008-GEN001-0003",
]


def test_two_of_three_user_ids_get_one_shop_hand() -> None:
    owned = 0
    seen: set[str] = set()
    for i in range(1, 301):
        design_id = assigned_hand_id(str(uuid.UUID(int=i)), HANDS)
        if design_id is None:
            continue
        owned += 1
        assert design_id in HANDS
        seen.add(design_id)
    assert owned == 200
    assert seen == set(HANDS)


def test_same_user_keeps_the_same_hand() -> None:
    user_id = "798a2f60-ebef-5a4e-ae6c-f49037d1d00a"
    first = assigned_hand_id(user_id, HANDS)
    assert first == assigned_hand_id(user_id, HANDS)
    assert assigned_hand_id("59b69ee3-7815-5a5d-84b1-865e1df05be2", HANDS) in (
        None,
        *HANDS,
    )


def test_empty_inputs_assign_nothing() -> None:
    assert assigned_hand_id("", HANDS) is None
    assert assigned_hand_id("798a2f60-ebef-5a4e-ae6c-f49037d1d00a", []) is None
