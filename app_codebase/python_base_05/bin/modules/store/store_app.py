"""Store HTTP routes (authuser catalog + Play / Apple verify)."""

from __future__ import annotations

from core.errors.app_error import AppError
from core.http.contracts.register_route_contract import ApplicationRouteSink
from core.http.contracts.response_contract import HttpResponseContract
from core.http.request_context import get_auth_user_id
from modules.auth.auth_service import parse_json_body
from modules.store.fragment_catalog import catalog_payload
from modules.store.store_errors import INVALID_QUERY
from modules.store.store_service import verify_apple_purchase, verify_play_purchase


def register_store_routes(
    routes: ApplicationRouteSink,
    res: HttpResponseContract,
) -> None:
    routes.authuser_get("/store/catalog", lambda: _handle_catalog(res))
    routes.authuser_post("/store/play/verify", lambda: _handle_play(res))
    routes.authuser_post("/store/apple/verify", lambda: _handle_apple(res))


def _require_user_id() -> str:
    user_id = get_auth_user_id()
    if not user_id:
        raise AppError(INVALID_QUERY, message="Unauthorized")
    return user_id


def _body_product_id(body: dict) -> str:
    product_id = str(body.get("productId") or body.get("product_id") or "").strip()
    if not product_id:
        raise AppError(INVALID_QUERY, message="productId is required")
    return product_id


def _handle_catalog(res: HttpResponseContract):
    try:
        _require_user_id()
        return res.json_ok(catalog_payload())
    except AppError as err:
        return err.to_http_response()


def _handle_play(res: HttpResponseContract):
    try:
        user_id = _require_user_id()
        body = parse_json_body() or {}
        product_id = _body_product_id(body)
        token = str(body.get("purchaseToken") or body.get("purchase_token") or "").strip()
        return res.json_ok(
            verify_play_purchase(
                user_id=user_id,
                product_id=product_id,
                purchase_token=token,
            )
        )
    except AppError as err:
        return err.to_http_response()


def _handle_apple(res: HttpResponseContract):
    try:
        user_id = _require_user_id()
        body = parse_json_body() or {}
        product_id = _body_product_id(body)
        signed = str(
            body.get("signedTransaction") or body.get("signed_transaction") or ""
        ).strip()
        transaction_id = str(
            body.get("transactionId") or body.get("transaction_id") or ""
        ).strip()
        return res.json_ok(
            verify_apple_purchase(
                user_id=user_id,
                product_id=product_id,
                signed_transaction=signed,
                transaction_id=transaction_id,
            )
        )
    except AppError as err:
        return err.to_http_response()
