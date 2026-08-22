"""Push inbox_changed events to all WS sessions for a user.

Local fan-out uses this worker's UserConnectionRegistry. When presence/Redis is
enabled, also publish so other Gunicorn workers can fan out to their local sockets.
"""

from __future__ import annotations

import json
import logging
import threading
from typing import Any

from redis import Redis
from redis.exceptions import RedisError

from core.cache.cache_config import redis_host, redis_password, redis_port
from core.presence.presence_config import presence_enabled, presence_key_prefix, worker_id
from core.state.connection_registry import ConnectionRegistry
from core.state.user_connection_registry import UserConnectionRegistry
from core.utils.dev_logger import customlog
from core.ws.response.ws_response import encode_ok

logger = logging.getLogger(__name__)

LOGGING_SWITCH = True

_INBOX_CHANNEL = "notifications/inbox"
_INBOX_EVENT = "inbox_changed"


def _pubsub_channel() -> str:
    return f"{presence_key_prefix()}inbox_changed"


class InboxBroadcaster:
    def __init__(
        self,
        *,
        connections: ConnectionRegistry,
        user_connections: UserConnectionRegistry,
    ) -> None:
        self._connections = connections
        self._user_connections = user_connections
        self._client: Redis | None = None
        self._listener_lock = threading.Lock()
        self._listener_started = False
        self._worker_id = worker_id()

    def start_cross_worker_listener(self) -> None:
        """Subscribe to Redis inbox_changed so this worker can push to local sockets."""
        if not presence_enabled():
            if LOGGING_SWITCH:
                customlog(
                    "inbox_broadcaster: cross-worker listener skipped "
                    "(ARCORI_PRESENCE_ENABLED off)"
                )
            return
        with self._listener_lock:
            if self._listener_started:
                return
            self._listener_started = True
        thread = threading.Thread(
            target=self._listen_loop,
            name="inbox-changed-pubsub",
            daemon=True,
        )
        thread.start()
        if LOGGING_SWITCH:
            customlog(
                f"inbox_broadcaster: cross-worker listener started "
                f"channel={_pubsub_channel()} worker={self._worker_id}"
            )

    def notify_inbox_changed(self, user_id: str) -> None:
        uid = user_id.strip()
        if not uid:
            return
        local_count = self._fanout_local(uid)
        published = self._publish_cross_worker(uid)
        if LOGGING_SWITCH:
            customlog(
                f"inbox_broadcaster: notify user={uid} local_connections={local_count} "
                f"published={published} worker={self._worker_id}"
            )

    def _fanout_local(self, uid: str) -> int:
        connection_ids = self._user_connections.connection_ids_for_user(uid)
        if not connection_ids:
            return 0
        frame = encode_ok(
            {
                "type": "event",
                "channel": _INBOX_CHANNEL,
                "payload": {"event": _INBOX_EVENT},
            }
        )
        delivered = 0
        for connection_id in connection_ids:
            try:
                self._connections.send(connection_id, frame)
                delivered += 1
            except Exception as exc:  # noqa: BLE001 — never fail create on push
                logger.warning(
                    "inbox_fanout_send_fail user=%s connection=%s error=%s",
                    uid,
                    connection_id,
                    exc,
                )
                if LOGGING_SWITCH:
                    customlog(
                        f"inbox_broadcaster: send failed user={uid} "
                        f"connection={connection_id} err={exc}"
                    )
        return delivered

    def _publish_cross_worker(self, uid: str) -> bool:
        if not presence_enabled():
            return False
        try:
            client = self._get_client()
            payload = json.dumps(
                {
                    "user_id": uid,
                    "origin_worker": self._worker_id,
                }
            )
            client.publish(_pubsub_channel(), payload)
            return True
        except RedisError as exc:
            logger.warning("inbox_pubsub_publish_fail user=%s error=%s", uid, exc)
            if LOGGING_SWITCH:
                customlog(f"inbox_broadcaster: publish failed user={uid} err={exc}")
            return False

    def _listen_loop(self) -> None:
        while True:
            try:
                # Dedicated client: pubsub.listen blocks longer than publish timeouts.
                client = self._build_client(socket_timeout=None)
                pubsub = client.pubsub(ignore_subscribe_messages=True)
                pubsub.subscribe(_pubsub_channel())
                if LOGGING_SWITCH:
                    customlog(
                        f"inbox_broadcaster: subscribed channel={_pubsub_channel()}"
                    )
                for message in pubsub.listen():
                    self._handle_pubsub_message(message)
            except RedisError as exc:
                logger.warning("inbox_pubsub_listen_fail error=%s", exc)
                if LOGGING_SWITCH:
                    customlog(f"inbox_broadcaster: listen error err={exc}")
            except Exception as exc:  # noqa: BLE001 — keep daemon alive
                logger.warning("inbox_pubsub_listen_unexpected error=%s", exc)
                if LOGGING_SWITCH:
                    customlog(f"inbox_broadcaster: listen unexpected err={exc}")
            threading.Event().wait(2.0)

    def _handle_pubsub_message(self, message: dict[str, Any]) -> None:
        if message.get("type") != "message":
            return
        raw = message.get("data")
        if not isinstance(raw, str):
            return
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            return
        if not isinstance(payload, dict):
            return
        origin = str(payload.get("origin_worker", "")).strip()
        if origin and origin == self._worker_id:
            return
        uid = str(payload.get("user_id", "")).strip()
        if not uid:
            return
        local_count = self._fanout_local(uid)
        if LOGGING_SWITCH:
            customlog(
                f"inbox_broadcaster: cross-worker deliver user={uid} "
                f"local_connections={local_count} from_worker={origin or '-'}"
            )

    def _get_client(self) -> Redis:
        if self._client is None:
            self._client = self._build_client(socket_timeout=2)
        return self._client

    def _build_client(self, *, socket_timeout: float | None) -> Redis:
        kwargs: dict[str, object] = {
            "host": redis_host(),
            "port": redis_port(),
            "decode_responses": True,
            "socket_connect_timeout": 2,
            "socket_timeout": socket_timeout,
        }
        password = redis_password()
        if password is not None:
            kwargs["password"] = password
        return Redis(**kwargs)
