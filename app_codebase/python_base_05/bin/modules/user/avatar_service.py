"""Avatar upload: validate, convert to WebP, persist on disk, update user row.

Claimed Kin face: ``users.avatar_url`` may point at ``/media/kin/players/*.json``
(Lottie). Uploaded photos stay under ``/media/avatars/``.
"""

from __future__ import annotations

import io
import os
from typing import Any

from PIL import Image, UnidentifiedImageError
from sqlalchemy.orm import Session

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

_KIN_LOTTIE_PREFIX = "/media/kin/players/"


def is_kin_lottie_avatar_url(url: str | None) -> bool:
    raw = (url or "").strip()
    return raw.startswith(_KIN_LOTTIE_PREFIX) and raw.endswith(".json")


def link_avatar_to_kin_lottie(
    session: Session,
    *,
    user_id: str,
    genesis_design_id: str,
) -> str:
    """Point ``users.avatar_url`` at the claimed Kin Lottie public path.

    Removes a previous uploaded WebP under ``/media/avatars/`` when replacing.
    Never deletes Kin player Lottie files.
    """
    from modules.catalog.kin_design_store import lottie_public_url

    public = lottie_public_url(genesis_design_id)
    user = user_repository.find_by_id(session, user_id)
    if user is None:
        return public
    previous = (user.avatar_url or "").strip() or None
    user.avatar_url = public
    session.flush()
    if previous and previous != public and not is_kin_lottie_avatar_url(previous):
        _delete_file_if_exists(_disk_path_from_public_url(previous))
    return public


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
        # Kin face is the profile pic after claim — do not replace with a photo.
        from modules.avari import avari_repository as avari_repo

        if avari_repo.find_player_kin(session, user_id) is not None:
            raise AuthServiceError(
                code="forbidden",
                message="Profile picture is your Kin face after claim",
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
            if not is_kin_lottie_avatar_url(previous_url):
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
        from modules.avari import avari_repository as avari_repo

        kin = avari_repo.find_player_kin(session, user_id)
        if kin is not None:
            # Keep / restore Kin Lottie link — cannot clear while Kin exists.
            public = link_avatar_to_kin_lottie(
                session,
                user_id=user_id,
                genesis_design_id=str(kin.genesis_design_id),
            )
            from modules.auth.auth_service import get_user_profile

            profile = get_user_profile(user_id)
            return {"profile": profile, "avatar_url": public}

        previous_url = user.avatar_url
        user.avatar_url = None
        session.flush()

    if previous_url and not is_kin_lottie_avatar_url(previous_url):
        _delete_file_if_exists(_disk_path_from_public_url(previous_url))

    from modules.auth.auth_service import get_user_profile

    profile = get_user_profile(user_id)
    return {"profile": profile}


def delete_avatar_file_for_user(user_id: str, avatar_url: str | None) -> None:
    if not avatar_url:
        return
    # Never delete claimed Kin Lottie media when clearing account / avatar.
    if is_kin_lottie_avatar_url(avatar_url):
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
