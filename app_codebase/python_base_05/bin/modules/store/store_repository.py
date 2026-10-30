"""store_fragment_purchases lookups."""

from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from models.store_fragment_purchase import StoreFragmentPurchase


def find_purchase(
    session: Session,
    *,
    platform: str,
    store_ref: str,
) -> StoreFragmentPurchase | None:
    return session.scalars(
        select(StoreFragmentPurchase).where(
            StoreFragmentPurchase.platform == platform,
            StoreFragmentPurchase.store_ref == store_ref,
        )
    ).first()


def insert_purchase(
    session: Session,
    *,
    user_id: uuid.UUID,
    platform: str,
    product_id: str,
    store_ref: str,
    fragments_credited: int,
    order_id: str | None,
    consume_ok: bool,
) -> StoreFragmentPurchase:
    row = StoreFragmentPurchase(
        user_id=user_id,
        platform=platform,
        product_id=product_id,
        store_ref=store_ref,
        fragments_credited=fragments_credited,
        order_id=order_id or None,
        consume_ok=consume_ok,
    )
    session.add(row)
    session.flush()
    return row
