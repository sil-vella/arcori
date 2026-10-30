"""Store verify settings. Paths must be readable by the API process."""

from __future__ import annotations

import os
from pathlib import Path


def _env(name: str) -> str:
    return os.environ.get(name, "").strip()


def google_play_package_name() -> str:
    return _env("GOOGLE_PLAY_PACKAGE_NAME") or "com.reignofplay.arcori"


def google_play_service_account_file() -> str:
    return _env("GOOGLE_PLAY_SERVICE_ACCOUNT_FILE")


def play_billing_configured() -> bool:
    path = google_play_service_account_file()
    return bool(google_play_package_name() and path and os.path.isfile(path))


def apple_bundle_id() -> str:
    return _env("APPLE_BUNDLE_ID") or "com.reignofplay.arcori"


def apple_issuer_id() -> str:
    return _env("APPLE_IAP_ISSUER_ID")


def apple_key_id() -> str:
    return _env("APPLE_IAP_KEY_ID")


def apple_private_key_file() -> str:
    return _env("APPLE_IAP_PRIVATE_KEY_FILE")


def apple_app_id() -> int | None:
    raw = _env("APPLE_APP_ID")
    if not raw:
        return None
    try:
        return int(raw)
    except ValueError:
        return None


def apple_environment_name() -> str:
    name = _env("APPLE_APP_STORE_ENVIRONMENT").lower()
    if name == "sandbox":
        return "sandbox"
    return "production"


def apple_root_certs_dir() -> Path:
    configured = _env("APPLE_ROOT_CERTS_DIR")
    if configured:
        return Path(configured)
    return Path(__file__).resolve().parent / "apple_root_certs"
