"""Sync global notifications seed tests."""

from __future__ import annotations

import json
import sys
import uuid
from pathlib import Path
from unittest.mock import MagicMock, patch

_REPO_ROOT = Path(__file__).resolve().parents[5]
_AUTOMATION_BACKEND = _REPO_ROOT / "automation" / "backend"
_PYTHON_BIN = _REPO_ROOT / "app_codebase" / "python_base_05" / "bin"

for path in (_AUTOMATION_BACKEND, _PYTHON_BIN):
    value = str(path)
    if value not in sys.path:
        sys.path.insert(0, value)

from sync_global_notifications import sync_global_notifications  # noqa: E402


def test_sync_global_notifications_upserts_seed(tmp_path: Path) -> None:
    global_id = "65f0a1b2-c3d4-e5f6-0718-290200000001"
    seed = {
        "messages": [
            {
                "id": global_id,
                "title": "Welcome",
                "body": "Hello",
                "type": "instant",
                "category": "system",
                "subtype": "welcome",
                "source": "global_broadcast",
                "data": {
                    "response": {
                        "type": "navigate",
                        "buttons": [
                            {"label": "Explore", "screen": "example_module"},
                        ],
                    }
                },
            }
        ]
    }
    seed_path = tmp_path / "global_notifications.json"
    seed_path.write_text(json.dumps(seed), encoding="utf-8")

    session = MagicMock()
    with patch("core.state.session_scope.session_scope") as mock_scope:
        mock_scope.return_value.__enter__.return_value = session
        with patch(
            "modules.notifications.notification_repository.upsert_global_notification",
        ) as upsert:
            result = sync_global_notifications(seed_path=seed_path, prune=False)

    assert result["upserted"] == 1
    assert result["pruned"] == 0
    upsert.assert_called_once()
    kwargs = upsert.call_args.kwargs
    assert kwargs["global_id"] == uuid.UUID(global_id)
    assert kwargs["data"]["response"]["type"] == "navigate"
