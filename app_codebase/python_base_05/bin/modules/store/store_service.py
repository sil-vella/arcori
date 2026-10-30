"""Credit Gold Fragments after a verified store purchase."""

from __future__ import annotations

import uuid

from sqlalchemy.exc import IntegrityError

from core.errors.app_error import AppError
from core.state.session_scope import session_scope
from core.utils.dev_logger import customlog
from modules.auth.auth_service import get_user_profile
from modules.avari import avari_repository as avari_repo
from modules.avari.gold_economy import apply_fragment_delta
from modules.store import apple_billing, play_billing, store_repository as repo
from modules.store.fragment_catalog import fragments_for_product
from modules.store.store_errors import INVALID_RECEIPT, RECEIPT_OWNED

LOGGING_SWITCH = True


def _wallet_payload(
    *,
    product_id: str,
    fragments_credited: int,
    gold_arcori: int,
    gold_fragments: int,
    idempotent: bool,
) -> dict:
    return {
        "productId": product_id,
        "fragmentsCredited": fragments_credited,
        "goldArcori": gold_arcori,
        "goldFragments": gold_fragments,
        "idempotent": idempotent,
    }


def _credit(
    *,
    user_id: str,
    platform: str,
    product_id: str,
    store_ref: str,
    fragments: int,
    order_id: str | None,
    consume_ok: bool,
) -> dict:
    uid = uuid.UUID(user_id)
    try:
        with session_scope() as session:
            existing = repo.find_purchase(
                session, platform=platform, store_ref=store_ref
            )
            if existing is not None:
                if existing.user_id != uid:
                    raise AppError(
                        RECEIPT_OWNED,
                        message="This purchase belongs to another account",
                    )
                avari = avari_repo.find_avari_profile(session, user_id)
                return _wallet_payload(
                    product_id=existing.product_id,
                    fragments_credited=int(existing.fragments_credited),
                    gold_arcori=int(avari.gold_arcori) if avari else 0,
                    gold_fragments=int(avari.gold_fragments) if avari else 0,
                    idempotent=True,
                )

            profile = get_user_profile(user_id)
            display_name = (
                str((profile or {}).get("username") or "").strip() or "Avari"
            )
            avari = avari_repo.ensure_avari_profile(
                session,
                user_id=uid,
                display_name=display_name,
            )
            after_a, after_f, _, _ = apply_fragment_delta(
                int(avari.gold_arcori),
                int(avari.gold_fragments),
                fragments,
            )
            avari.gold_arcori = after_a
            avari.gold_fragments = after_f
            repo.insert_purchase(
                session,
                user_id=uid,
                platform=platform,
                product_id=product_id,
                store_ref=store_ref,
                fragments_credited=fragments,
                order_id=order_id,
                consume_ok=consume_ok,
            )
            if LOGGING_SWITCH:
                customlog(
                    f"store: credited user={user_id} platform={platform} "
                    f"product={product_id} fragments={fragments} "
                    f"goldArcori={after_a} frags={after_f}"
                )
            return _wallet_payload(
                product_id=product_id,
                fragments_credited=fragments,
                gold_arcori=after_a,
                gold_fragments=after_f,
                idempotent=False,
            )
    except IntegrityError:
        with session_scope() as session:
            existing = repo.find_purchase(
                session, platform=platform, store_ref=store_ref
            )
            if existing is None or existing.user_id != uid:
                raise AppError(RECEIPT_OWNED)
            avari = avari_repo.find_avari_profile(session, user_id)
            return _wallet_payload(
                product_id=existing.product_id,
                fragments_credited=int(existing.fragments_credited),
                gold_arcori=int(avari.gold_arcori) if avari else 0,
                gold_fragments=int(avari.gold_fragments) if avari else 0,
                idempotent=True,
            )


def verify_play_purchase(*, user_id: str, product_id: str, purchase_token: str) -> dict:
    token = (purchase_token or "").strip()
    if not token:
        raise AppError(INVALID_RECEIPT, message="purchase_token is required")
    fragments = fragments_for_product(product_id)
    receipt = play_billing.fetch_product_purchase(product_id, token)
    already_consumed = receipt.consumption_state == 1
    payload = _credit(
        user_id=user_id,
        platform="play",
        product_id=product_id,
        store_ref=token,
        fragments=fragments,
        order_id=receipt.order_id or None,
        consume_ok=already_consumed,
    )
    if payload["idempotent"] or already_consumed:
        return payload
    consumed = play_billing.consume_product_purchase(product_id, token)
    if consumed:
        with session_scope() as session:
            row = repo.find_purchase(session, platform="play", store_ref=token)
            if row is not None:
                row.consume_ok = True
    elif LOGGING_SWITCH:
        customlog(f"store: play consume pending product={product_id}")
    return payload


def verify_apple_purchase(
    *,
    user_id: str,
    product_id: str,
    signed_transaction: str,
    transaction_id: str,
) -> dict:
    fragments = fragments_for_product(product_id)
    verified_id = apple_billing.resolve_apple_transaction(
        signed_transaction=signed_transaction,
        transaction_id=transaction_id,
        expected_product_id=product_id,
    )
    return _credit(
        user_id=user_id,
        platform="apple",
        product_id=product_id,
        store_ref=verified_id,
        fragments=fragments,
        order_id=None,
        consume_ok=True,
    )
