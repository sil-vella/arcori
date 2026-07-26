"""Avari profile read — identity from user row + empty game stubs."""

from __future__ import annotations

from typing import Any

from core.errors.app_error import AppError
from modules.auth.auth_service import get_user_profile
from modules.avari.avari_errors import INVALID_QUERY, NOT_FOUND


def get_avari_profile(user_id: str) -> dict[str, Any]:
    uid = (user_id or "").strip()
    if not uid:
        raise AppError(INVALID_QUERY, message="Unauthorized")

    profile = get_user_profile(uid)
    if profile is None:
        raise AppError(NOT_FOUND, message="Avari profile not found")

    display_name = str(profile.get("username") or "").strip() or "Avari"
    account_type = str(profile.get("account_type") or "Regular")

    return {
        "identity": {
            "userId": str(profile.get("user_id") or uid),
            "displayName": display_name,
            "email": profile.get("email"),
            "avatarUrl": profile.get("avatar_url"),
            "accountType": account_type,
            "title": "Avari",
        },
        "rank": {
            "xp": 0,
            "level": 1,
            "label": None,
        },
        "titles": ["Avari"],
        "kin": None,
        "mastery": {
            "designsTracked": 0,
            "top": [],
        },
        "stats": {
            "matchesPlayed": 0,
            "wins": 0,
            "flips": 0,
        },
    }
