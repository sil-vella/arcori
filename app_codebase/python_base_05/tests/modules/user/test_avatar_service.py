"""Avatar upload service tests."""

from __future__ import annotations

import io
import os
import tempfile
import unittest
import uuid
from unittest.mock import MagicMock, patch

from PIL import Image

from modules.auth.auth_service import AuthServiceError
from modules.user.avatar_service import delete_avatar, upload_avatar


class _FakeUser:
    def __init__(
        self,
        *,
        user_id: uuid.UUID | None = None,
        avatar_url: str | None = None,
    ) -> None:
        self.id = user_id or uuid.uuid4()
        self.avatar_url = avatar_url


def _png_bytes(width: int = 64, height: int = 64) -> bytes:
    img = Image.new("RGB", (width, height), color=(120, 80, 200))
    out = io.BytesIO()
    img.save(out, format="PNG")
    return out.getvalue()


class AvatarServiceTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmpdir = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmpdir.cleanup)
        self._env_patch = patch.dict(
            os.environ,
            {
                "UPLOAD_ROOT": self._tmpdir.name,
                "AVATAR_MAX_UPLOAD_BYTES": "2097152",
                "AVATAR_MAX_DIMENSION": "512",
                "AVATAR_WEBP_QUALITY": "82",
            },
        )
        self._env_patch.start()
        self.addCleanup(self._env_patch.stop)

    @patch("modules.auth.auth_service.get_user_profile")
    @patch("modules.user.avatar_service.session_scope")
    @patch("modules.user.avatar_service.user_repository")
    def test_upload_avatar_success(
        self,
        repo: MagicMock,
        scope: MagicMock,
        get_profile: MagicMock,
    ) -> None:
        session = MagicMock()
        scope.return_value.__enter__.return_value = session
        user = _FakeUser()
        repo.find_by_id.return_value = user
        get_profile.return_value = {
            "user_id": str(user.id),
            "username": "testuser",
            "email": "test@example.com",
            "is_guest": False,
            "account_type": "Regular",
            "avatar_url": f"/media/avatars/{user.id}.webp",
            "created_at": "2026-01-01T00:00:00+00:00",
        }

        payload = upload_avatar(user_id=str(user.id), raw_bytes=_png_bytes())

        self.assertTrue(payload["avatar_url"].endswith(".webp"))
        disk_path = os.path.join(self._tmpdir.name, "avatars", f"{user.id}.webp")
        self.assertTrue(os.path.isfile(disk_path))
        self.assertEqual(user.avatar_url, payload["avatar_url"])

    @patch("modules.user.avatar_service.session_scope")
    @patch("modules.user.avatar_service.user_repository")
    def test_upload_avatar_rejects_oversized(
        self,
        repo: MagicMock,
        scope: MagicMock,
    ) -> None:
        with patch.dict(os.environ, {"AVATAR_MAX_UPLOAD_BYTES": "10"}):
            with self.assertRaises(AuthServiceError) as ctx:
                upload_avatar(user_id=str(uuid.uuid4()), raw_bytes=_png_bytes())
        self.assertEqual(ctx.exception.code, "invalid_request")
        repo.find_by_id.assert_not_called()

    @patch("modules.user.avatar_service.session_scope")
    @patch("modules.user.avatar_service.user_repository")
    def test_upload_avatar_rejects_invalid_bytes(
        self,
        repo: MagicMock,
        scope: MagicMock,
    ) -> None:
        with self.assertRaises(AuthServiceError) as ctx:
            upload_avatar(user_id=str(uuid.uuid4()), raw_bytes=b"not-an-image")
        self.assertEqual(ctx.exception.code, "invalid_request")

    @patch("modules.auth.auth_service.get_user_profile")
    @patch("modules.user.avatar_service.session_scope")
    @patch("modules.user.avatar_service.user_repository")
    def test_reupload_replaces_file(
        self,
        repo: MagicMock,
        scope: MagicMock,
        get_profile: MagicMock,
    ) -> None:
        session = MagicMock()
        scope.return_value.__enter__.return_value = session
        user = _FakeUser()
        repo.find_by_id.return_value = user
        get_profile.return_value = {"user_id": str(user.id), "avatar_url": "x"}

        upload_avatar(user_id=str(user.id), raw_bytes=_png_bytes(32, 32))
        first_mtime = os.path.getmtime(
            os.path.join(self._tmpdir.name, "avatars", f"{user.id}.webp")
        )
        upload_avatar(user_id=str(user.id), raw_bytes=_png_bytes(128, 96))
        second_mtime = os.path.getmtime(
            os.path.join(self._tmpdir.name, "avatars", f"{user.id}.webp")
        )
        self.assertGreaterEqual(second_mtime, first_mtime)

    @patch("modules.auth.auth_service.get_user_profile")
    @patch("modules.user.avatar_service.session_scope")
    @patch("modules.user.avatar_service.user_repository")
    def test_delete_avatar_clears_file(
        self,
        repo: MagicMock,
        scope: MagicMock,
        get_profile: MagicMock,
    ) -> None:
        session = MagicMock()
        scope.return_value.__enter__.return_value = session
        user = _FakeUser()
        repo.find_by_id.return_value = user
        get_profile.return_value = {"user_id": str(user.id), "avatar_url": None}

        upload_avatar(user_id=str(user.id), raw_bytes=_png_bytes())
        disk_path = os.path.join(self._tmpdir.name, "avatars", f"{user.id}.webp")
        self.assertTrue(os.path.isfile(disk_path))

        user.avatar_url = f"/media/avatars/{user.id}.webp"
        delete_avatar(user_id=str(user.id))
        self.assertFalse(os.path.isfile(disk_path))
        self.assertIsNone(user.avatar_url)


if __name__ == "__main__":
    unittest.main()
