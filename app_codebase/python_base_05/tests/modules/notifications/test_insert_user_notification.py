"""Notification insert idempotency on msg_id."""

from __future__ import annotations

import unittest
import uuid
from unittest.mock import MagicMock, patch

from modules.notifications import notification_repository as repo


class InsertUserNotificationTests(unittest.TestCase):
    def test_null_msg_id_uses_plain_add(self) -> None:
        session = MagicMock()
        row = repo.insert_user_notification(
            session,
            user_id=uuid.uuid4(),
            source="achievements",
            notification_type="instant",
            title="T",
            body="B",
            msg_id=None,
        )
        session.add.assert_called_once()
        session.flush.assert_called()
        self.assertIsNotNone(row)

    @patch("modules.notifications.notification_repository.insert")
    def test_same_msg_id_conflict_returns_existing(
        self, insert_fn: MagicMock
    ) -> None:
        session = MagicMock()
        uid = uuid.uuid4()
        existing_id = uuid.uuid4()
        existing = MagicMock()
        existing.id = existing_id
        existing.msg_id = "achievement_unlock:u:a:m"

        # INSERT … ON CONFLICT returns no row
        stmt = MagicMock()
        insert_fn.return_value.values.return_value.on_conflict_do_nothing.return_value.returning.return_value = (
            stmt
        )
        session.execute.return_value.first.return_value = None
        session.scalars.return_value.first.return_value = existing

        row = repo.insert_user_notification(
            session,
            user_id=uid,
            source="achievements",
            notification_type="instant",
            title="Unlocked",
            body="You unlocked",
            category="progress",
            subtype="achievement_unlock",
            msg_id="achievement_unlock:u:a:m",
        )
        self.assertIs(row, existing)
        session.add.assert_not_called()


if __name__ == "__main__":
    unittest.main()
