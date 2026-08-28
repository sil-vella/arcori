# dash Ensure FB/YT/TT tokens (auto-extend / refresh + persist rotations)
"""Silent token renewal for Marketing publish, metrics, and cron.

- YouTube / TikTok: exchange refresh → access; persist rotated refresh_token.
- Facebook: debug Page token; auto fb_exchange_token when expiry is near.
- invalid_grant / revoked refresh cannot be fixed without browser OAuth —
  callers get TokenRenewError with *_reauth_required codes.

Used by publish runners and the dashboard — keep out of the interactive menu
noise via wfrun_excluded_scripts.txt (ensure_platform_tokens.py stays listed).
"""

from __future__ import annotations

import json
import time
import urllib.parse
from typing import Any

from publish_common import env, http_json, persist_env_key

GRAPH = "https://graph.facebook.com/v21.0"
GOOGLE_TOKEN_URI = "https://oauth2.googleapis.com/token"
TIKTOK_TOKEN_URI = "https://open.tiktokapis.com/v2/oauth/token/"

# Extend FB Page token when debug_token expiry is within this window.
FB_EXTEND_WITHIN_SECONDS = 14 * 24 * 3600


class TokenRenewError(RuntimeError):
    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message

    def as_err_result(self) -> dict[str, Any]:
        return {"ok": False, "error": {"code": self.code, "message": self.message}}


def _payload_looks_invalid_grant(payload: dict[str, Any] | str) -> bool:
    text = payload if isinstance(payload, str) else json.dumps(payload)
    lower = text.lower()
    return "invalid_grant" in lower or "token has been expired or revoked" in lower


def youtube_access_token(*, persist_rotated: bool = True) -> str:
    """Refresh YouTube access token; persist new refresh_token when Google rotates it."""
    client_id = env("YOUTUBE_CLIENT_ID")
    client_secret = env("YOUTUBE_CLIENT_SECRET")
    refresh_token = env("YOUTUBE_REFRESH_TOKEN")
    if not client_id or not client_secret or not refresh_token:
        raise TokenRenewError(
            "missing_youtube_credentials",
            "Set YOUTUBE_CLIENT_ID, YOUTUBE_CLIENT_SECRET, YOUTUBE_REFRESH_TOKEN",
        )
    status, payload, _ = http_json(
        "POST",
        GOOGLE_TOKEN_URI,
        form={
            "client_id": client_id,
            "client_secret": client_secret,
            "refresh_token": refresh_token,
            "grant_type": "refresh_token",
        },
        timeout=60,
    )
    access = str(payload.get("access_token") or "").strip()
    if status >= 400 or not access:
        if _payload_looks_invalid_grant(payload):
            raise TokenRenewError(
                "youtube_reauth_required",
                "YouTube refresh token expired or revoked — run "
                "automation/marketing/youtube_oauth_get_refresh_token.py "
                "(Brand Account) and write YOUTUBE_REFRESH_TOKEN to env.",
            )
        raise TokenRenewError(
            "youtube_token_refresh_failed",
            f"youtube_token_refresh_failed: {payload!r}",
        )
    new_refresh = str(payload.get("refresh_token") or "").strip()
    if persist_rotated and new_refresh and new_refresh != refresh_token:
        persist_env_key("YOUTUBE_REFRESH_TOKEN", new_refresh)
    return access


def tiktok_access_token(*, persist_rotated: bool = True) -> str:
    """Refresh TikTok access token; always persist rotated refresh_token when returned."""
    client_key = env("TIKTOK_CLIENT_KEY")
    client_secret = env("TIKTOK_CLIENT_SECRET")
    refresh_token = env("TIKTOK_REFRESH_TOKEN")
    if not client_key or not client_secret or not refresh_token:
        raise TokenRenewError(
            "missing_tiktok_credentials",
            "Set TIKTOK_CLIENT_KEY, TIKTOK_CLIENT_SECRET, TIKTOK_REFRESH_TOKEN",
        )
    status, payload, _ = http_json(
        "POST",
        TIKTOK_TOKEN_URI,
        form={
            "client_key": client_key,
            "client_secret": client_secret,
            "grant_type": "refresh_token",
            "refresh_token": refresh_token,
        },
        headers={"Cache-Control": "no-cache"},
        timeout=60,
    )
    if "data" in payload and isinstance(payload["data"], dict):
        payload = {**payload, **payload["data"]}
    access = str(payload.get("access_token") or "").strip()
    if status >= 400 or not access:
        if _payload_looks_invalid_grant(payload):
            raise TokenRenewError(
                "tiktok_reauth_required",
                "TikTok refresh token expired or revoked — run "
                "automation/marketing/tiktok_oauth_get_refresh_token.py "
                "and write TIKTOK_REFRESH_TOKEN to env.",
            )
        raise TokenRenewError(
            "tiktok_token_refresh_failed",
            f"tiktok_token_refresh_failed: {payload!r}",
        )
    new_refresh = str(payload.get("refresh_token") or "").strip()
    if persist_rotated and new_refresh and new_refresh != refresh_token:
        persist_env_key("TIKTOK_REFRESH_TOKEN", new_refresh)
    return access


def _fb_app_token(app_id: str, app_secret: str) -> str:
    return f"{app_id}|{app_secret}"


def _fb_debug_token(input_token: str, app_token: str) -> dict[str, Any]:
    qs = urllib.parse.urlencode(
        {"input_token": input_token, "access_token": app_token}
    )
    status, payload, _ = http_json("GET", f"{GRAPH}/debug_token?{qs}", timeout=45)
    if status >= 400 or payload.get("error"):
        err = payload.get("error") if isinstance(payload.get("error"), dict) else payload
        raise TokenRenewError(
            "facebook_token_debug_failed",
            f"debug_token failed: {err!r}",
        )
    data = payload.get("data") if isinstance(payload.get("data"), dict) else {}
    if not data:
        raise TokenRenewError("facebook_token_debug_failed", "debug_token empty")
    return data


def _fb_exchange(app_id: str, app_secret: str, token: str) -> str:
    qs = urllib.parse.urlencode(
        {
            "grant_type": "fb_exchange_token",
            "client_id": app_id,
            "client_secret": app_secret,
            "fb_exchange_token": token,
        }
    )
    status, payload, _ = http_json(
        "GET", f"{GRAPH}/oauth/access_token?{qs}", timeout=45
    )
    if status >= 400 or payload.get("error"):
        err = payload.get("error") if isinstance(payload.get("error"), dict) else payload
        raise TokenRenewError(
            "facebook_reauth_required",
            "Facebook token exchange failed — re-mint Page token via Graph Explorer "
            f"or facebook_validate_page_token.py --extend. Graph: {err!r}",
        )
    new_token = str(payload.get("access_token") or "").strip()
    if not new_token:
        raise TokenRenewError(
            "facebook_reauth_required",
            f"fb_exchange_token returned no access_token: {payload!r}",
        )
    return new_token


def _fb_page_token_from_user(page_id: str, user_or_page_token: str) -> str | None:
    qs = urllib.parse.urlencode(
        {"fields": "id,name,access_token", "access_token": user_or_page_token}
    )
    status, payload, _ = http_json(
        "GET", f"{GRAPH}/{urllib.parse.quote(page_id)}?{qs}", timeout=45
    )
    if status >= 400 or payload.get("error"):
        return None
    return str(payload.get("access_token") or "").strip() or None


def facebook_page_token(
    *,
    auto_extend: bool = True,
    extend_within_seconds: int = FB_EXTEND_WITHIN_SECONDS,
    persist: bool = True,
) -> str:
    """Return a usable Page token; auto-extend when expiry is near and persist."""
    app_id = env("FACEBOOK_APP_ID")
    app_secret = env("FACEBOOK_APP_SECRET")
    page_id = env("FACEBOOK_PAGE_ID")
    page_token = env("FACEBOOK_PAGE_ACCESS_TOKEN")
    if not page_token:
        raise TokenRenewError(
            "missing_facebook_credentials",
            "Need FACEBOOK_PAGE_ACCESS_TOKEN",
        )
    if not app_id or not app_secret or not page_id:
        # Still allow publish with raw page token if app creds missing
        return page_token

    app_token = _fb_app_token(app_id, app_secret)
    try:
        data = _fb_debug_token(page_token, app_token)
    except TokenRenewError:
        if not auto_extend:
            raise
        # Fall through to exchange attempt
        data = {"is_valid": False, "expires_at": 1}

    is_valid = bool(data.get("is_valid"))
    expires_at = data.get("expires_at")
    try:
        expires_at_i = int(expires_at) if expires_at is not None else 0
    except (TypeError, ValueError):
        expires_at_i = 0

    needs_extend = False
    if auto_extend:
        if not is_valid:
            needs_extend = True
        elif expires_at_i > 0:
            remaining = expires_at_i - int(time.time())
            if remaining <= extend_within_seconds:
                needs_extend = True

    if not needs_extend:
        if not is_valid:
            raise TokenRenewError(
                "facebook_reauth_required",
                "FACEBOOK_PAGE_ACCESS_TOKEN is invalid — re-mint via Graph Explorer "
                "or facebook_validate_page_token.py --extend --write-env.",
            )
        return page_token

    source = env("FACEBOOK_USER_ACCESS_TOKEN") or page_token
    exchanged = _fb_exchange(app_id, app_secret, source)
    try:
        exchanged_debug = _fb_debug_token(exchanged, app_token)
    except TokenRenewError:
        exchanged_debug = {}

    final = exchanged
    if (exchanged_debug.get("type") or "").lower() != "page":
        resolved = _fb_page_token_from_user(page_id, exchanged)
        if not resolved:
            raise TokenRenewError(
                "facebook_reauth_required",
                "Token exchange did not yield a Page token — mint via "
                "GET /{page-id}?fields=access_token then update "
                "FACEBOOK_PAGE_ACCESS_TOKEN.",
            )
        final = resolved

    if persist and final and final != page_token:
        persist_env_key("FACEBOOK_PAGE_ACCESS_TOKEN", final)
    return final


def ensure_marketing_tokens(
    *,
    platforms: list[str] | None = None,
) -> dict[str, Any]:
    """Renew tokens for selected platforms. Returns {ok, platforms: {name: status}}."""
    wanted = [p.strip().lower() for p in (platforms or ["facebook", "youtube", "tiktok"])]
    out: dict[str, Any] = {}
    all_ok = True
    for name in wanted:
        try:
            if name == "facebook":
                if not env("FACEBOOK_PAGE_ACCESS_TOKEN"):
                    out[name] = {"ok": True, "skipped": True, "reason": "not_configured"}
                    continue
                token = facebook_page_token()
                out[name] = {"ok": True, "token_len": len(token)}
            elif name == "youtube":
                if not env("YOUTUBE_REFRESH_TOKEN"):
                    out[name] = {"ok": True, "skipped": True, "reason": "not_configured"}
                    continue
                token = youtube_access_token()
                out[name] = {"ok": True, "access_len": len(token)}
            elif name == "tiktok":
                if not env("TIKTOK_REFRESH_TOKEN"):
                    out[name] = {"ok": True, "skipped": True, "reason": "not_configured"}
                    continue
                token = tiktok_access_token()
                out[name] = {"ok": True, "access_len": len(token)}
            else:
                out[name] = {"ok": False, "error": {"code": "unknown_platform", "message": name}}
                all_ok = False
        except TokenRenewError as exc:
            all_ok = False
            out[name] = {"ok": False, "error": {"code": exc.code, "message": exc.message}}
        except Exception as exc:  # noqa: BLE001 — boundary status for dash/cron
            all_ok = False
            out[name] = {
                "ok": False,
                "error": {"code": f"{name}_token_error", "message": str(exc)},
            }
    return {"ok": all_ok, "platforms": out}
