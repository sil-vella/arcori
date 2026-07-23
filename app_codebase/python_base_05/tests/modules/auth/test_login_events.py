"""Login event repository and request metadata tests."""

from __future__ import annotations

import unittest
import uuid
from unittest.mock import MagicMock, patch

from core.http.request_context import get_client_ip, get_user_agent
from modules.auth.auth_service import login, register
from modules.auth.login_event_repository import record_login_event


class RequestContextMetaTests(unittest.TestCase):
    def test_get_client_ip_from_forwarded_header(self) -> None:
        request = MagicMock()
        request.headers = {"X-Forwarded-For": "203.0.113.1, 10.0.0.1"}
        request.client = MagicMock(host="127.0.0.1")

        with patch("core.http.request_context.get_current_request", return_value=request):
            self.assertEqual(get_client_ip(), "203.0.113.1")

    def test_get_user_agent_truncates(self) -> None:
        request = MagicMock()
        request.headers = {"User-Agent": "x" * 600}

        with patch("core.http.request_context.get_current_request", return_value=request):
            self.assertEqual(len(get_user_agent() or ""), 512)


class LoginEventRecordingTests(unittest.TestCase):
    @patch("modules.auth.auth_service.enforce_auth_identity_rate_limit")
    @patch("modules.auth.auth_service.get_refresh_session_store")
    @patch("modules.auth.auth_service._record_login_event")
    @patch("modules.auth.auth_service.session_scope")
    @patch("modules.auth.auth_service.user_repository")
    def test_login_records_event(
        self,
        repo: MagicMock,
        scope: MagicMock,
        record: MagicMock,
        get_store: MagicMock,
        _rl: MagicMock,
    ) -> None:
        from core.auth.contracts.auth_context_contract import AuthContext
        from tests.modules.auth.test_auth_service import _FakeUser

        session = MagicMock()
        scope.return_value.__enter__.return_value = session
        user = _FakeUser(password="guestabc123456")
        repo.find_by_email.return_value = user
        get_store.return_value = MagicMock()

        with patch("modules.auth.auth_service.token_service") as token_service:
            token_service.issue_access.return_value = "access-token"
            token_service.issue_refresh.return_value = "refresh-token"
            token_service.verify_refresh.return_value = AuthContext(
                user_id=str(user.id),
                claims={"jti": "jti-1", "typ": "refresh", "sub": str(user.id)},
            )
            login(email="guestabc@arcori.arcori", password="guestabc123456")

        record.assert_called_once_with(str(user.id))

    @patch("modules.auth.auth_service.session_scope")
    def test_record_login_event_persists_row(self, scope: MagicMock) -> None:
        session = MagicMock()
        scope.return_value.__enter__.return_value = session
        user_id = str(uuid.uuid4())

        record_login_event(
            session,
            user_id=user_id,
            client_ip="192.168.1.10",
            user_agent="FlutterTest/1.0",
        )

        session.add.assert_called_once()
        session.flush.assert_called_once()


if __name__ == "__main__":
    unittest.main()
