"""Market slammer SKUs — every non-permanent Shop slammer."""

from __future__ import annotations

from typing import Any

# Genesis shop defaults. Catalog economy overrides these when present.
# Starter stays permanent and is never a Market SKU.
DEFAULT_SHOP_PRICE_GOLD_ARCORI = 4
DEFAULT_RECHARGE_PRICE_GOLD_ARCORI = 4
DEFAULT_RECHARGE_CHARGES = 100
DEFAULT_MAX_CHARGES = 25
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


def is_shop_slammer(design: dict[str, Any] | None, *, design_id: str = "") -> bool:
    """True when this catalog design is sold on the Market.

    Shop slammers only. Permanent / Starter / any other origin stay off the shelf.
    """
    if not isinstance(design, dict):
        return False
    iid = (design_id or str(design.get("internalId") or "")).strip()
    code = str(design.get("designCode") or "").strip().upper()
    origin = str(design.get("origin") or "").strip().lower()
    eco = design.get("economy") if isinstance(design.get("economy"), dict) else {}
    if bool(eco.get("permanent")) or code == "STR" or origin == "starter":
        return False
    if origin != "shop":
        return False
    theme = str(design.get("themeCode") or "").strip().upper()
    dtype = str(design.get("type") or "").strip().lower()
    if theme == "SLM" or dtype == "slammer" or iid.upper().startswith("SLM-"):
        return True
    return False
