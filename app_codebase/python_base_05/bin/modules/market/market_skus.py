"""Market slammer SKUs (v1: Rim only)."""

from __future__ import annotations

from typing import Any

# Genesis Rim — Market Slammers section v1.
MARKET_SLAMMER_IDS: tuple[str, ...] = ("SLM-RIM-SER001-GEN001-0011",)

DEFAULT_SHOP_PRICE_GOLD_ARCORI = 4
DEFAULT_RECHARGE_PRICE_GOLD_ARCORI = 4
DEFAULT_RECHARGE_CHARGES = 100
DEFAULT_MAX_CHARGES = 20
DEFAULT_CHARGE_COST_PER_USE = 1


def parse_slammer_economy(design: dict[str, Any] | None) -> dict[str, Any]:
    """Normalize catalog economy for Market + charge spend."""
    raw = design.get("economy") if isinstance(design, dict) else None
    eco = raw if isinstance(raw, dict) else {}

    permanent = bool(eco.get("permanent"))

    def _int(key: str, *aliases: str, default: int) -> int:
        for k in (key, *aliases):
            v = eco.get(k)
            if isinstance(v, bool):
                continue
            if isinstance(v, int):
                return max(0, v)
            if isinstance(v, float):
                return max(0, int(v))
            if isinstance(v, str) and v.strip().isdigit():
                return max(0, int(v.strip()))
        return default

    max_charges = None if permanent else _int(
        "maxCharges", default=DEFAULT_MAX_CHARGES
    )
    return {
        "permanent": permanent,
        "maxCharges": max_charges,
        "chargeCostPerUse": _int(
            "chargeCostPerUse", default=DEFAULT_CHARGE_COST_PER_USE
        ),
        "shopPriceGoldArcori": _int(
            "shopPriceGoldArcori",
            default=DEFAULT_SHOP_PRICE_GOLD_ARCORI,
        ),
        "rechargePriceGoldArcori": _int(
            "rechargePriceGoldArcori",
            default=DEFAULT_RECHARGE_PRICE_GOLD_ARCORI,
        ),
        "rechargeCharges": _int(
            "rechargeCharges",
            default=DEFAULT_RECHARGE_CHARGES,
        ),
    }


def is_market_slammer(design_id: str) -> bool:
    did = (design_id or "").strip()
    return did in MARKET_SLAMMER_IDS
