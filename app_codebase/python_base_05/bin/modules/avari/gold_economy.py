"""Gold Fragments / Gold Arcori wallet helpers (currency only — not catalog)."""

from __future__ import annotations

FRAGMENTS_PER_GOLD_ARCORI = 4
DEFAULT_MATCH_FEE_FRAGMENTS = 2
SIGNUP_GOLD_ARCORI = 20


def match_fee_fragments(
    match_type: str | None,
    *,
    event_id: str | None = None,
) -> int:
    """Fee charged pre-match for online modes. Practice is free (callers skip pay)."""
    eid = (event_id or "").strip()
    code = (match_type or "").strip()
    if eid or code in ("specialEvent", "special_event"):
        try:
            from modules.special_events.special_events_service import (
                match_fee_for_event,
            )

            return match_fee_for_event(eid or None)
        except Exception:
            pass
    return DEFAULT_MATCH_FEE_FRAGMENTS


def normalize_wallet(gold_arcori: int, gold_fragments: int) -> tuple[int, int]:
    """Fold every 4 fragments into Gold Arcori; remainder stays 0..3."""
    arcori = max(0, int(gold_arcori))
    frags = int(gold_fragments)
    if frags >= FRAGMENTS_PER_GOLD_ARCORI or frags < 0:
        total = arcori * FRAGMENTS_PER_GOLD_ARCORI + frags
        if total < 0:
            return 0, 0
        arcori = total // FRAGMENTS_PER_GOLD_ARCORI
        frags = total % FRAGMENTS_PER_GOLD_ARCORI
    return arcori, frags


def total_fragments(gold_arcori: int, gold_fragments: int) -> int:
    """Wallet as total Gold Fragments (Gold Arcori × 4 + remainder)."""
    arcori, frags = normalize_wallet(gold_arcori, gold_fragments)
    return arcori * FRAGMENTS_PER_GOLD_ARCORI + frags


def can_afford_fragments(
    gold_arcori: int,
    gold_fragments: int,
    cost_fragments: int,
) -> bool:
    """True when wallet covers ``cost_fragments`` (cost ≤ 0 always ok)."""
    cost = int(cost_fragments)
    if cost <= 0:
        return True
    return total_fragments(gold_arcori, gold_fragments) >= cost


def apply_fragment_delta(
    gold_arcori: int,
    gold_fragments: int,
    delta_fragments: int,
) -> tuple[int, int, int, int]:
    """
    Apply a net fragment delta, converting Gold Arcori ↔ fragments as needed.

    Returns (new_arcori, new_fragments, arcori_delta, fragments_field_delta)
    where fragments_field_delta is change to the stored remainder field after normalize
    (not the net economic delta). Prefer reporting economic net via delta_fragments.

    Negative deltas that would go below zero clamp to empty wallet — callers that
    must reject insufficient funds should check [can_afford_fragments] first.
    """
    before_a, before_f = normalize_wallet(gold_arcori, gold_fragments)
    total = before_a * FRAGMENTS_PER_GOLD_ARCORI + before_f + int(delta_fragments)
    if total < 0:
        total = 0
    after_a = total // FRAGMENTS_PER_GOLD_ARCORI
    after_f = total % FRAGMENTS_PER_GOLD_ARCORI
    return after_a, after_f, after_a - before_a, after_f - before_f
