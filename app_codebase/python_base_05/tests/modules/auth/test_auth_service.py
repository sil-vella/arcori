"""Auth service unit tests."""

from __future__ import annotations

import unittest
import uuid
from unittest.mock import MagicMock, patch

from core.auth.contracts.auth_context_contract import AuthContext
from modules.auth.auth_service import AuthServiceError, delete_account, login, register
from modules.auth.password_utils import hash_password, verify_password


def _refresh_ctx(user_id: str, jti: str = "jti-1") -> AuthContext:
    return AuthContext(
        user_id=user_id,
        claims={"sub": user_id, "typ": "refresh", "jti": jti},
    )


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
        self.password_hash = hash_password(password)
        self.is_guest = is_guest
        self.avatar_url = None
        self.email_verified_at = None


class PasswordUtilsTests(unittest.TestCase):
    def test_hash_and_verify(self) -> None:
        hashed = hash_password("guestabc123456")
        self.assertTrue(verify_password("guestabc123456", hashed))
        self.assertFalse(verify_password("wrong", hashed))


class RegisterTests(unittest.TestCase):
    @patch("modules.auth.auth_service.avari_repo.ensure_avari_profile")
    @patch("modules.auth.auth_service.enforce_guest_register_rate_limit")
    @patch("modules.auth.auth_service.enforce_auth_identity_rate_limit")
    @patch("modules.auth.auth_service.get_refresh_session_store")
    @patch("modules.auth.auth_service.session_scope")
    @patch("modules.auth.auth_service.user_repository")
    def test_register_success(
        self,
        repo: MagicMock,
        scope: MagicMock,
        get_store: MagicMock,
        _rl: MagicMock,
        _guest_rl: MagicMock,
        ensure_profile: MagicMock,
    ) -> None:
        session = MagicMock()
        scope.return_value.__enter__.return_value = session
        repo.find_by_email.return_value = None
        repo.find_by_username.return_value = None
        user = _FakeUser(username="guestabc", email="guestabc@arcori.arcori")
        repo.create_user.return_value = user
        store = MagicMock()
        get_store.return_value = store

        with patch("modules.auth.auth_service.token_service") as token_service:
            token_service.issue_access.return_value = "access-token"
            token_service.issue_refresh.return_value = "refresh-token"
            token_service.verify_refresh.return_value = _refresh_ctx(str(user.id))
            payload = register(
                username="guestabc",
                email="guestabc@arcori.arcori",
                password="guestabc123456",
                is_guest=True,
            )

        self.assertEqual(payload["user_id"], str(user.id))
        self.assertEqual(payload["access_token"], "access-token")
        self.assertEqual(payload["refresh_token"], "refresh-token")
        self.assertTrue(payload["is_guest"])
        store.set_current_jti.assert_called_once_with(str(user.id), "jti-1")
        ensure_profile.assert_called_once()

    @patch("modules.auth.auth_service.enforce_auth_identity_rate_limit")
    @patch("modules.auth.auth_service.session_scope")
    @patch("modules.auth.auth_service.user_repository")
    def test_register_duplicate_email(
        self, repo: MagicMock, scope: MagicMock, _rl: MagicMock
    ) -> None:
        session = MagicMock()
        scope.return_value.__enter__.return_value = session
        repo.find_by_email.return_value = _FakeUser(
            email="user@example.com", is_guest=False
        )

        with self.assertRaises(AuthServiceError) as ctx:
            register(
                username="otheruser",
                email="user@example.com",
                password="guestabc123456",
            )

        self.assertEqual(ctx.exception.code, "email_taken")
        self.assertEqual(ctx.exception.status, 409)


class LoginTests(unittest.TestCase):
    @patch("modules.auth.auth_service.avari_repo.ensure_avari_profile")
    @patch("modules.auth.auth_service.enforce_auth_identity_rate_limit")
    @patch("modules.auth.auth_service.get_refresh_session_store")
    @patch("modules.auth.auth_service.session_scope")
    @patch("modules.auth.auth_service.user_repository")
    def test_login_success(
        self, repo: MagicMock, scope: MagicMock, get_store: MagicMock, _rl: MagicMock,
        ensure_profile: MagicMock,
    ) -> None:
        session = MagicMock()
        scope.return_value.__enter__.return_value = session
        user = _FakeUser(password="guestabc123456")
        repo.find_by_email.return_value = user
        get_store.return_value = MagicMock()

        with patch("modules.auth.auth_service.token_service") as token_service:
            token_service.issue_access.return_value = "access-token"
            token_service.issue_refresh.return_value = "refresh-token"
            token_service.verify_refresh.return_value = _refresh_ctx(str(user.id))
            payload = login(
                email="guestabc@arcori.arcori",
                password="guestabc123456",
            )

        self.assertEqual(payload["user_id"], str(user.id))
        self.assertTrue(payload["is_guest"])
        ensure_profile.assert_called_once()

    @patch("modules.auth.auth_service.enforce_auth_identity_rate_limit")
    @patch("modules.auth.auth_service.session_scope")
    @patch("modules.auth.auth_service.user_repository")
    def test_login_invalid_password(
        self, repo: MagicMock, scope: MagicMock, _rl: MagicMock
    ) -> None:
        session = MagicMock()
        scope.return_value.__enter__.return_value = session
        repo.find_by_email.return_value = _FakeUser(password="correct")

        with self.assertRaises(AuthServiceError) as ctx:
            login(email="guestabc@arcori.arcori", password="wrong")

        self.assertEqual(ctx.exception.code, "invalid_credentials")
        self.assertEqual(ctx.exception.status, 401)


class DeleteAccountTests(unittest.TestCase):
    @patch("modules.auth.auth_service.revoke_refresh_session")
    @patch("modules.user.avatar_service.delete_avatar_file_for_user")
    @patch("modules.auth.auth_service.session_scope")
    @patch("modules.auth.auth_service.user_repository")
    def test_delete_account_success(
        self, repo: MagicMock, scope: MagicMock, _avatar: MagicMock, revoke: MagicMock
    ) -> None:
        session = MagicMock()
        scope.return_value.__enter__.return_value = session
        user = _FakeUser(password="guestabc123456", is_guest=False)
        repo.find_by_id.return_value = user
        repo.delete_by_id.return_value = True

        delete_account(
            user_id=str(user.id),
            password="guestabc123456",
            confirmation="DELETE",
        )

        repo.delete_by_id.assert_called_once()
        revoke.assert_called_once_with(str(user.id), reason="delete")

    @patch("modules.auth.auth_service.session_scope")
    @patch("modules.auth.auth_service.user_repository")
    def test_delete_account_wrong_confirmation(
        self, repo: MagicMock, scope: MagicMock
    ) -> None:
        with self.assertRaises(AuthServiceError) as ctx:
            delete_account(
                user_id=str(uuid.uuid4()),
                password="secret",
                confirmation="delete",
            )

        self.assertEqual(ctx.exception.code, "invalid_request")
        repo.find_by_id.assert_not_called()

    @patch("modules.auth.auth_service.session_scope")
    @patch("modules.auth.auth_service.user_repository")
    def test_delete_account_invalid_password(
        self, repo: MagicMock, scope: MagicMock
    ) -> None:
        session = MagicMock()
        scope.return_value.__enter__.return_value = session
        repo.find_by_id.return_value = _FakeUser(password="correct", is_guest=False)

        with self.assertRaises(AuthServiceError) as ctx:
            delete_account(
                user_id=str(uuid.uuid4()),
                password="wrong",
                confirmation="DELETE",
            )

        self.assertEqual(ctx.exception.code, "invalid_credentials")
        repo.delete_by_id.assert_not_called()

    @patch("modules.auth.auth_service.session_scope")
    @patch("modules.auth.auth_service.user_repository")
    def test_delete_account_rejects_guest(self, repo: MagicMock, scope: MagicMock) -> None:
        session = MagicMock()
        scope.return_value.__enter__.return_value = session
        repo.find_by_id.return_value = _FakeUser(password="guestabc123456", is_guest=True)

        with self.assertRaises(AuthServiceError) as ctx:
            delete_account(
                user_id=str(uuid.uuid4()),
                password="guestabc123456",
                confirmation="DELETE",
            )

        self.assertEqual(ctx.exception.code, "forbidden")
        repo.delete_by_id.assert_not_called()


if __name__ == "__main__":
    unittest.main()
