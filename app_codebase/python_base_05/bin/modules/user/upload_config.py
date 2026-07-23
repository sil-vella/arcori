"""Avatar upload configuration from environment."""

from __future__ import annotations

import os

DEFAULT_UPLOAD_ROOT = "/data/uploads"
DEFAULT_MAX_UPLOAD_BYTES = 2 * 1024 * 1024
DEFAULT_MAX_DIMENSION = 512
DEFAULT_WEBP_QUALITY = 82


def upload_root() -> str:
    return os.environ.get("UPLOAD_ROOT", DEFAULT_UPLOAD_ROOT).strip() or DEFAULT_UPLOAD_ROOT


def avatar_max_upload_bytes() -> int:
    raw = os.environ.get("AVATAR_MAX_UPLOAD_BYTES", str(DEFAULT_MAX_UPLOAD_BYTES))
    try:
        return max(1, int(raw))
    except ValueError:
        return DEFAULT_MAX_UPLOAD_BYTES


def avatar_max_dimension() -> int:
    raw = os.environ.get("AVATAR_MAX_DIMENSION", str(DEFAULT_MAX_DIMENSION))
    try:
        return max(1, int(raw))
    except ValueError:
        return DEFAULT_MAX_DIMENSION


def avatar_webp_quality() -> int:
    raw = os.environ.get("AVATAR_WEBP_QUALITY", str(DEFAULT_WEBP_QUALITY))
    try:
        return min(100, max(1, int(raw)))
    except ValueError:
        return DEFAULT_WEBP_QUALITY


def public_media_base_url() -> str:
    return os.environ.get("PUBLIC_MEDIA_BASE_URL", "").strip().rstrip("/")


def avatar_public_path(user_id: str) -> str:
    return f"/media/avatars/{user_id}.webp"


def avatar_disk_path(user_id: str) -> str:
    return os.path.join(upload_root(), "avatars", f"{user_id}.webp")
