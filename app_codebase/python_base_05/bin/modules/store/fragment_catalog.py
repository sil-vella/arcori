"""Gold Fragment store catalog. Amounts and USD labels match Dutch coin packs."""

from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path
from typing import Any

from core.errors.app_error import AppError
from modules.store.store_errors import UNKNOWN_PRODUCT

_CATALOG_PATH = Path(__file__).with_name("fragment_catalog.json")


@lru_cache(maxsize=1)
def load_catalog() -> dict[str, Any]:
    raw = json.loads(_CATALOG_PATH.read_text(encoding="utf-8"))
    if not isinstance(raw, dict):
        raise AppError(UNKNOWN_PRODUCT, message="Fragment catalog is unreadable")
    return raw


def catalog_packs() -> list[dict[str, Any]]:
    packs = load_catalog().get("packs") or []
    rows: list[dict[str, Any]] = []
    for item in packs:
        if not isinstance(item, dict):
            continue
        product_id = str(item.get("product_id") or "").strip()
        fragments = int(item.get("fragments") or 0)
        if not product_id or fragments <= 0:
            continue
        rows.append(
            {
                "productId": product_id,
                "fragments": fragments,
                "priceLabel": str(item.get("price_label") or ""),
                "label": str(item.get("label") or product_id),
                "description": str(item.get("description") or ""),
                "isPopular": bool(item.get("is_popular")),
            }
        )
    return rows


def fragments_for_product(product_id: str) -> int:
    wanted = (product_id or "").strip()
    for row in catalog_packs():
        if row["productId"] == wanted:
            return int(row["fragments"])
    raise AppError(UNKNOWN_PRODUCT, message="Unknown fragment pack")


def catalog_payload() -> dict[str, Any]:
    return {"packs": catalog_packs()}
