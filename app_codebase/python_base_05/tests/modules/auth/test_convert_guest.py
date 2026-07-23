"""Guest-to-full account conversion tests."""

from __future__ import annotations

import unittest
import uuid
from unittest.mock import MagicMock, patch

from modules.auth.auth_service import AuthServiceError, convert_guest_account


class _FakeUser:
    def __init__(
        self,
        *,
        user_id: uuid.UUID | None = None,
        username: str = "guestabc",
        email: str = "guestabc@arcori.arcori",
        password: str = "secret",
        is_guest: bool = True,
    ) -> None:
        self.id = user_id or uuid.uuid4()
        self.username = username
        self.email = email
        self.password_hash = password
        self.is_guest = is_guest


class ConvertGuestAccountTests(unittest.TestCase):
    @patch("modules.auth.auth_service.revoke_refresh_session")
    @patch("modules.auth.auth_service._record_login_event")
    @patch("modules.auth.auth_service.get_refresh_session_store")
    @patch("modules.auth.auth_service.session_scope")
    @patch("modules.auth.auth_service.user_repository")
    def test_convert_guest_success(
        self,
        repo: MagicMock,
        scope: MagicMock,
        get_store: MagicMock,
        _,
        revoke: MagicMock,
    ) -> None:
        session = MagicMock()
        scope.return_value.__enter__.return_value = session
        user = _FakeUser()
        repo.find_by_id.return_value = user
        repo.email_taken_by_other.return_value = False
        repo.username_taken_by_other.return_value = False
        get_store.return_value = MagicMock()

        with patch("modules.auth.auth_service.token_service") as token_service:
            token_service.issue_access.return_value = "access-token"
            token_service.issue_refresh.return_value = "refresh-token"
            from core.auth.contracts.auth_context_contract import AuthContext

            token_service.verify_refresh.return_value = AuthContext(
                user_id=str(user.id),
                claims={"jti": "jti-1", "typ": "refresh", "sub": str(user.id)},
            )
            payload = convert_guest_account(
                user_id=str(user.id),
                guest_email="guestabc@arcori.arcori",
                username="realuser",
                email="real@example.com",
                password="newpass123456",
            )

        self.assertEqual(payload["user_id"], str(user.id))
        self.assertEqual(payload["access_token"], "access-token")
        self.assertEqual(payload["refresh_token"], "refresh-token")
        self.assertFalse(payload["is_guest"])
        repo.upgrade_guest_to_full.assert_called_once()
        revoke.assert_called_once_with(str(user.id), reason="convert")

    @patch("modules.auth.auth_service.session_scope")
    @patch("modules.auth.auth_service.user_repository")
    def test_convert_guest_wrong_guest_email(
        self, repo: MagicMock, scope: MagicMock
    ) -> None:
        session = MagicMock()
        scope.return_value.__enter__.return_value = session
        user = _FakeUser(email="guestabc@arcori.arcori")
        repo.find_by_id.return_value = user

        with self.assertRaises(AuthServiceError) as ctx:
            convert_guest_account(
                user_id=str(user.id),
                guest_email="other@arcori.arcori",
                username="realuser",
                email="real@example.com",
                password="newpass123456",
            )

        self.assertEqual(ctx.exception.code, "invalid_request")
        self.assertEqual(ctx.exception.status, 400)
        repo.upgrade_guest_to_full.assert_not_called()

    @patch("modules.auth.auth_service.session_scope")
    @patch("modules.auth.auth_service.user_repository")
    def test_convert_guest_non_guest_user(
        self, repo: MagicMock, scope: MagicMock
    ) -> None:
        session = MagicMock()
        scope.return_value.__enter__.return_value = session
        user = _FakeUser(
            email="real@example.com",
            is_guest=False,
        )
        repo.find_by_id.return_value = user

        with self.assertRaises(AuthServiceError) as ctx:
            convert_guest_account(
                user_id=str(user.id),
                guest_email="real@example.com",
                username="realuser",
                email="real@example.com",
                password="newpass123456",
            )

        self.assertEqual(ctx.exception.code, "forbidden")
        self.assertEqual(ctx.exception.status, 403)

    @patch("modules.auth.auth_service.session_scope")
    @patch("modules.auth.auth_service.user_repository")
    def test_convert_guest_email_collision(
        self, repo: MagicMock, scope: MagicMock
    ) -> None:
        session = MagicMock()
        scope.return_value.__enter__.return_value = session
        user = _FakeUser()
        repo.find_by_id.return_value = user
        repo.email_taken_by_other.return_value = True

        with self.assertRaises(AuthServiceError) as ctx:
            convert_guest_account(
                user_id=str(user.id),
                guest_email="guestabc@arcori.arcori",
                username="realuser",
                email="taken@example.com",
                password="newpass123456",
            )

        self.assertEqual(ctx.exception.code, "email_taken")
        self.assertEqual(ctx.exception.status, 409)

    @patch("modules.auth.auth_service.session_scope")
    @patch("modules.auth.auth_service.user_repository")
    def test_convert_guest_username_collision(
        self, repo: MagicMock, scope: MagicMock
    ) -> None:
        session = MagicMock()
        scope.return_value.__enter__.return_value = session
        user = _FakeUser()
        repo.find_by_id.return_value = user
        repo.email_taken_by_other.return_value = False
        repo.username_taken_by_other.return_value = True

        with self.assertRaises(AuthServiceError) as ctx:
            convert_guest_account(
                user_id=str(user.id),
                guest_email="guestabc@arcori.arcori",
                username="takenuser",
                email="real@example.com",
                password="newpass123456",
            )

        self.assertEqual(ctx.exception.code, "username_taken")
        self.assertEqual(ctx.exception.status, 409)

    @patch("modules.auth.auth_service.revoke_refresh_session")
    @patch("modules.auth.auth_service._record_login_event")
    @patch("modules.auth.auth_service.get_refresh_session_store")
    @patch("modules.auth.auth_service.session_scope")
    @patch("modules.auth.auth_service.user_repository")
    def test_convert_guest_unchanged_username_allowed(
        self, repo: MagicMock, scope: MagicMock, get_store: MagicMock, _, revoke: MagicMock
    ) -> None:
        session = MagicMock()
        scope.return_value.__enter__.return_value = session
        user = _FakeUser(username="guestabc")
        repo.find_by_id.return_value = user
        repo.email_taken_by_other.return_value = False
        repo.username_taken_by_other.return_value = False
        get_store.return_value = MagicMock()

        with patch("modules.auth.auth_service.token_service") as token_service:
            token_service.issue_access.return_value = "access-token"
            token_service.issue_refresh.return_value = "refresh-token"
            from core.auth.contracts.auth_context_contract import AuthContext

            token_service.verify_refresh.return_value = AuthContext(
                user_id=str(user.id),
                claims={"jti": "jti-1", "typ": "refresh", "sub": str(user.id)},
            )
            payload = convert_guest_account(
                user_id=str(user.id),
                guest_email="guestabc@arcori.arcori",
                username="guestabc",
                email="real@example.com",
                password="newpass123456",
            )

        self.assertFalse(payload["is_guest"])
        repo.upgrade_guest_to_full.assert_called_once()
        revoke.assert_called_once_with(str(user.id), reason="convert")

    @patch("modules.auth.auth_service.session_scope")
    @patch("modules.auth.auth_service.user_repository")
    def test_convert_guest_rejects_guest_email(
        self, repo: MagicMock, scope: MagicMock
    ) -> None:
        with self.assertRaises(AuthServiceError) as ctx:
            convert_guest_account(
                user_id=str(uuid.uuid4()),
                guest_email="guestabc@arcori.arcori",
                username="realuser",
                email="newguest@arcori.arcori",
                password="newpass123456",
            )

        self.assertEqual(ctx.exception.code, "invalid_request")
        repo.find_by_id.assert_not_called()


if __name__ == "__main__":
    unittest.main()
