"""Avatar upload: validate, convert to WebP, persist on disk, update user row."""

from __future__ import annotations

import io
import os
from typing import Any

from PIL import Image, UnidentifiedImageError

from core.state.session_scope import session_scope
from modules.auth.auth_service import AuthServiceError
from modules.auth import user_repository
from modules.user.upload_config import (
    avatar_disk_path,
    avatar_max_dimension,
    avatar_max_upload_bytes,
    avatar_public_path,
    avatar_webp_quality,
    upload_root,
)

ALLOWED_FORMATS = frozenset({"JPEG", "PNG", "WEBP"})


def upload_avatar(*, user_id: str, raw_bytes: bytes) -> dict[str, Any]:
    if not raw_bytes:
        raise AuthServiceError(
            code="invalid_request",
            message="Avatar file is required",
            status=400,
        )
    if len(raw_bytes) > avatar_max_upload_bytes():
        raise AuthServiceError(
            code="invalid_request",
            message="Avatar file exceeds maximum size (2 MB)",
            status=400,
        )

    try:
        processed = _process_image(raw_bytes)
    except AuthServiceError:
        raise
    except Exception as exc:
        raise AuthServiceError(
            code="invalid_request",
            message="Unsupported or corrupt image file",
            status=400,
        ) from exc

    public_path = avatar_public_path(user_id)
    disk_path = avatar_disk_path(user_id)

    with session_scope() as session:
        user = user_repository.find_by_id(session, user_id)
        if user is None:
            raise AuthServiceError(
                code="not_found",
                message="User not found",
                status=404,
            )
        if user.is_guest:
            raise AuthServiceError(
                code="forbidden",
                message="Guest accounts cannot upload a profile picture",
                status=403,
            )
        previous_url = user.avatar_url
        try:
            _write_avatar_file(disk_path, processed)
        except OSError as exc:
            raise AuthServiceError(
                code="internal_error",
                message="Failed to save avatar",
                status=500,
            ) from exc
        user.avatar_url = public_path
        session.flush()
        if previous_url and previous_url != public_path:
            _delete_file_if_exists(_disk_path_from_public_url(previous_url))

    from modules.auth.auth_service import get_user_profile

    profile = get_user_profile(user_id)
    return {
        "avatar_url": public_path,
        "profile": profile,
    }


def delete_avatar(*, user_id: str) -> dict[str, Any]:
    with session_scope() as session:
        user = user_repository.find_by_id(session, user_id)
        if user is None:
            raise AuthServiceError(
                code="not_found",
                message="User not found",
                status=404,
            )
        if user.is_guest:
            raise AuthServiceError(
                code="forbidden",
                message="Guest accounts cannot upload a profile picture",
                status=403,
            )
        previous_url = user.avatar_url
        user.avatar_url = None
        session.flush()

    if previous_url:
        _delete_file_if_exists(_disk_path_from_public_url(previous_url))

    from modules.auth.auth_service import get_user_profile

    profile = get_user_profile(user_id)
    return {"profile": profile}


def delete_avatar_file_for_user(user_id: str, avatar_url: str | None) -> None:
    if not avatar_url:
        return
    expected = avatar_public_path(user_id)
    if avatar_url != expected:
        _delete_file_if_exists(_disk_path_from_public_url(avatar_url))
        return
    _delete_file_if_exists(avatar_disk_path(user_id))


def _process_image(raw_bytes: bytes) -> bytes:
    try:
        with Image.open(io.BytesIO(raw_bytes)) as img:
            fmt = (img.format or "").upper()
            if fmt not in ALLOWED_FORMATS:
                raise AuthServiceError(
                    code="invalid_request",
                    message="Only JPEG, PNG, and WebP images are allowed",
                    status=400,
                )
            img.load()
            if img.mode in ("RGBA", "LA", "P"):
                img = img.convert("RGBA")
                background = Image.new("RGB", img.size, (255, 255, 255))
                background.paste(img, mask=img.split()[-1])
                img = background
            elif img.mode != "RGB":
                img = img.convert("RGB")
            max_dim = avatar_max_dimension()
            img.thumbnail((max_dim, max_dim), Image.Resampling.LANCZOS)
            out = io.BytesIO()
            img.save(
                out,
                format="WEBP",
                quality=avatar_webp_quality(),
                method=6,
            )
            return out.getvalue()
    except UnidentifiedImageError as exc:
        raise AuthServiceError(
            code="invalid_request",
            message="Unsupported or corrupt image file",
            status=400,
        ) from exc


def _write_avatar_file(disk_path: str, data: bytes) -> None:
    os.makedirs(os.path.dirname(disk_path), exist_ok=True)
    temp_path = f"{disk_path}.tmp"
    with open(temp_path, "wb") as handle:
        handle.write(data)
    os.replace(temp_path, disk_path)


def _disk_path_from_public_url(public_url: str) -> str:
    prefix = "/media/"
    if public_url.startswith(prefix):
        relative = public_url[len(prefix) :]
        return os.path.join(upload_root(), relative)
    return os.path.join(upload_root(), public_url.lstrip("/"))


def _delete_file_if_exists(path: str) -> None:
    try:
        if os.path.isfile(path):
            os.remove(path)
    except OSError:
        pass
