"""Google Play product-purchase lookup for consumable fragment packs."""

from __future__ import annotations

from dataclasses import dataclass
from urllib.parse import quote

import httpx

from core.errors.app_error import AppError
from core.utils.dev_logger import customlog
from modules.store.store_config import (
    google_play_package_name,
    google_play_service_account_file,
    play_billing_configured,
)
from modules.store.store_errors import INVALID_RECEIPT, NOT_CONFIGURED, VERIFY_FAILED

LOGGING_SWITCH = True

_SCOPE = "https://www.googleapis.com/auth/androidpublisher"
_BASE = "https://androidpublisher.googleapis.com/androidpublisher/v3"


@dataclass(frozen=True)
class PlayReceipt:
    order_id: str
    consumption_state: int


def interpret_product_purchase(body: dict) -> PlayReceipt:
    """purchaseState 0 is purchased. consumptionState 1 means Play already consumed it."""
    try:
        purchase_state = int(body.get("purchaseState", -1))
        consumption_state = int(body.get("consumptionState", -1))
    except (TypeError, ValueError) as exc:
        raise AppError(INVALID_RECEIPT, message="Play purchase payload is invalid") from exc
    if purchase_state != 0:
        raise AppError(INVALID_RECEIPT, message="Purchase is not paid")
    return PlayReceipt(
        order_id=str(body.get("orderId") or ""),
        consumption_state=consumption_state,
    )


def _bearer() -> str:
    if not play_billing_configured():
        raise AppError(
            NOT_CONFIGURED,
            message="Set GOOGLE_PLAY_SERVICE_ACCOUNT_FILE for Play verification",
        )
    from google.auth.transport.requests import Request
    from google.oauth2 import service_account

    creds = service_account.Credentials.from_service_account_file(
        google_play_service_account_file(),
        scopes=[_SCOPE],
    )
    creds.refresh(Request())
    token = creds.token or ""
    if not token:
        raise AppError(VERIFY_FAILED, message="Play credentials did not return a token")
    return token


def _product_url(package: str, product_id: str, purchase_token: str) -> str:
    token = quote(purchase_token, safe="")
    return (
        f"{_BASE}/applications/{quote(package, safe='')}"
        f"/purchases/products/{quote(product_id, safe='')}/tokens/{token}"
    )


def fetch_product_purchase(product_id: str, purchase_token: str) -> PlayReceipt:
    package = google_play_package_name()
    url = _product_url(package, product_id, purchase_token)
    try:
        response = httpx.get(
            url,
            headers={"Authorization": f"Bearer {_bearer()}"},
            timeout=20.0,
        )
    except httpx.HTTPError as exc:
        if LOGGING_SWITCH:
            customlog(f"store: play get failed product={product_id} err={exc}")
        raise AppError(VERIFY_FAILED, message="Play verification failed") from exc
    if response.status_code == 404:
        raise AppError(INVALID_RECEIPT, message="Play purchase was not found")
    if response.status_code >= 400:
        if LOGGING_SWITCH:
            customlog(
                f"store: play get status={response.status_code} product={product_id}"
            )
        raise AppError(VERIFY_FAILED, message="Play verification failed")
    try:
        body = response.json()
    except ValueError as exc:
        raise AppError(VERIFY_FAILED, message="Play verification failed") from exc
    if not isinstance(body, dict):
        raise AppError(VERIFY_FAILED, message="Play verification failed")
    return interpret_product_purchase(body)


def consume_product_purchase(product_id: str, purchase_token: str) -> bool:
    package = google_play_package_name()
    url = _product_url(package, product_id, purchase_token) + ":consume"
    try:
        response = httpx.post(
            url,
            headers={"Authorization": f"Bearer {_bearer()}"},
            timeout=20.0,
        )
    except httpx.HTTPError as exc:
        if LOGGING_SWITCH:
            customlog(f"store: play consume failed product={product_id} err={exc}")
        return False
    if response.status_code >= 400:
        if LOGGING_SWITCH:
            customlog(
                f"store: play consume status={response.status_code} product={product_id}"
            )
        return False
    return True
