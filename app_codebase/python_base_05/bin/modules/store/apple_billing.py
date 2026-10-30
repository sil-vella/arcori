"""App Store Server API + StoreKit 2 JWS checks for fragment packs."""

from __future__ import annotations

import os
from functools import lru_cache
from typing import Any

from core.errors.app_error import AppError
from core.utils.dev_logger import customlog
from modules.store.store_config import (
    apple_app_id,
    apple_bundle_id,
    apple_environment_name,
    apple_issuer_id,
    apple_key_id,
    apple_private_key_file,
    apple_root_certs_dir,
)
from modules.store.store_errors import INVALID_RECEIPT, NOT_CONFIGURED, VERIFY_FAILED

LOGGING_SWITCH = True


def _load_private_key() -> bytes | None:
    path = apple_private_key_file()
    if path and os.path.isfile(path):
        return open(path, "rb").read()
    return None


def _load_root_certificates() -> list[bytes]:
    folder = apple_root_certs_dir()
    if not folder.is_dir():
        return []
    certs: list[bytes] = []
    for path in sorted(folder.glob("*.cer")):
        certs.append(path.read_bytes())
    return certs


def apple_billing_configured() -> bool:
    return bool(
        apple_issuer_id()
        and apple_key_id()
        and apple_bundle_id()
        and _load_private_key()
        and _load_root_certificates()
    )


def _env_try_order() -> tuple[str, str]:
    primary = apple_environment_name()
    secondary = "sandbox" if primary == "production" else "production"
    return primary, secondary


def _environment(env_name: str):
    from appstoreserverlibrary.models.Environment import Environment

    if env_name == "sandbox":
        return Environment.SANDBOX
    return Environment.PRODUCTION


@lru_cache(maxsize=2)
def _verifier(env_name: str):
    from appstoreserverlibrary.signed_data_verifier import SignedDataVerifier

    root_certs = _load_root_certificates()
    bundle_id = apple_bundle_id()
    if not root_certs or not bundle_id:
        return None
    environment = _environment(env_name)
    app_id = apple_app_id()
    from appstoreserverlibrary.models.Environment import Environment

    if environment == Environment.PRODUCTION and app_id is None:
        return None
    return SignedDataVerifier(root_certs, True, environment, bundle_id, app_id)


@lru_cache(maxsize=2)
def _api_client(env_name: str):
    from appstoreserverlibrary.api_client import AppStoreServerAPIClient

    private_key = _load_private_key()
    issuer = apple_issuer_id()
    key_id = apple_key_id()
    bundle_id = apple_bundle_id()
    if not private_key or not issuer or not key_id or not bundle_id:
        return None
    return AppStoreServerAPIClient(
        private_key,
        key_id,
        issuer,
        bundle_id,
        _environment(env_name),
    )


def _payload_from_decoded(decoded: Any) -> dict[str, Any]:
    transaction_id = str(getattr(decoded, "transactionId", None) or "").strip()
    original = str(getattr(decoded, "originalTransactionId", None) or transaction_id).strip()
    revocation = getattr(decoded, "revocationDate", None)
    return {
        "transaction_id": transaction_id,
        "original_transaction_id": original,
        "product_id": str(getattr(decoded, "productId", None) or "").strip(),
        "bundle_id": str(getattr(decoded, "bundleId", None) or "").strip(),
        "revoked_ms": int(revocation) if revocation else None,
    }


def _verify_signed(signed_transaction: str) -> dict[str, Any]:
    from appstoreserverlibrary.signed_data_verifier import VerificationException

    last_err = "verification failed"
    saw = False
    for env_name in _env_try_order():
        verifier = _verifier(env_name)
        if verifier is None:
            continue
        saw = True
        try:
            decoded = verifier.verify_and_decode_signed_transaction(signed_transaction)
            return _payload_from_decoded(decoded)
        except VerificationException as exc:
            last_err = str(exc)
        except Exception as exc:
            last_err = str(exc)
    if not saw:
        raise AppError(
            NOT_CONFIGURED,
            message="Set APPLE_IAP_ISSUER_ID, APPLE_IAP_KEY_ID, APPLE_IAP_PRIVATE_KEY_FILE, and APPLE_APP_ID",
        )
    if LOGGING_SWITCH:
        customlog(f"store: apple jws rejected err={last_err}")
    raise AppError(INVALID_RECEIPT, message="Apple could not confirm this purchase")


def _fetch_by_id(transaction_id: str) -> dict[str, Any]:
    from appstoreserverlibrary.api_client import APIException

    last_err = "Transaction not found"
    saw = False
    for env_name in _env_try_order():
        client = _api_client(env_name)
        if client is None:
            continue
        saw = True
        try:
            response = client.get_transaction_info(transaction_id)
            signed = getattr(response, "signedTransactionInfo", None) or ""
            if not signed:
                continue
            return _verify_signed(signed)
        except APIException as exc:
            last_err = str(exc)
        except AppError:
            raise
        except Exception as exc:
            last_err = str(exc)
    if not saw:
        raise AppError(NOT_CONFIGURED, message="Apple IAP API client is not configured")
    if LOGGING_SWITCH:
        customlog(f"store: apple lookup failed err={last_err}")
    raise AppError(VERIFY_FAILED, message="Apple verification failed")


def resolve_apple_transaction(
    *,
    signed_transaction: str,
    transaction_id: str,
    expected_product_id: str,
) -> str:
    """Return the verified transaction id for the ledger."""
    if not apple_billing_configured():
        raise AppError(
            NOT_CONFIGURED,
            message="Set APPLE_IAP_ISSUER_ID, APPLE_IAP_KEY_ID, and APPLE_IAP_PRIVATE_KEY_FILE",
        )
    signed = (signed_transaction or "").strip()
    tid = (transaction_id or "").strip()
    if signed:
        payload = _verify_signed(signed)
    elif tid:
        payload = _fetch_by_id(tid)
    else:
        raise AppError(INVALID_RECEIPT, message="signed_transaction or transaction_id is required")

    actual = str(payload.get("product_id") or "")
    expected = (expected_product_id or "").strip()
    if expected and actual and expected != actual:
        raise AppError(INVALID_RECEIPT, message="product_id does not match the App Store transaction")
    bundle_actual = str(payload.get("bundle_id") or "")
    if bundle_actual and bundle_actual != apple_bundle_id():
        raise AppError(INVALID_RECEIPT, message="This purchase is for a different app")
    if payload.get("revoked_ms"):
        raise AppError(INVALID_RECEIPT, message="This purchase was revoked")
    verified = str(payload.get("transaction_id") or "").strip()
    if not verified:
        raise AppError(INVALID_RECEIPT, message="Apple transaction id is missing")
    return verified


def clear_apple_clients_for_tests() -> None:
    _verifier.cache_clear()
    _api_client.cache_clear()
