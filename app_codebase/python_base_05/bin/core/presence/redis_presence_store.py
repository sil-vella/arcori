"""Redis-backed presence store shared across Gunicorn workers."""

from __future__ import annotations

import logging

from redis import Redis
from redis.exceptions import RedisError

from core.cache.cache_config import redis_host, redis_password, redis_port
from core.presence.in_memory_presence_store import InMemoryPresenceStore
from core.presence.presence_config import presence_key_prefix, presence_session_ttl_seconds
from core.presence.presence_types import UserSession

logger = logging.getLogger(__name__)


class RedisPresenceStore:
    def __init__(self) -> None:
        self._client: Redis | None = None
        self._fallback = InMemoryPresenceStore()

    def is_enabled(self) -> bool:
        return True

    def _full_key(self, suffix: str) -> str:
        return f"{presence_key_prefix()}{suffix}"

    def _session_key(self, session_id: str) -> str:
        return self._full_key(f"session:{session_id}")

    def _user_key(self, user_id: str) -> str:
        return self._full_key(f"user:{user_id}")

    def _get_client(self) -> Redis:
        if self._client is None:
            kwargs: dict[str, object] = {
                "host": redis_host(),
                "port": redis_port(),
                "decode_responses": True,
                "socket_connect_timeout": 2,
                "socket_timeout": 2,
            }
            password = redis_password()
            if password is not None:
                kwargs["password"] = password
            self._client = Redis(**kwargs)
        return self._client

    def register_session(
        self,
        *,
        session_id: str,
        user_id: str,
        worker_id: str,
        tier: str,
        connected_at: str,
        last_seen_at: str,
    ) -> None:
        sid = session_id.strip()
        uid = user_id.strip()
        if not sid or not uid:
            return
        ttl = presence_session_ttl_seconds()
        try:
            client = self._get_client()
            pipe = client.pipeline()
            pipe.hset(
                self._session_key(sid),
                mapping={
                    "user_id": uid,
                    "worker_id": worker_id,
                    "tier": tier,
                    "connected_at": connected_at,
                    "last_seen_at": last_seen_at,
                },
            )
            pipe.expire(self._session_key(sid), ttl)
            pipe.sadd(self._user_key(uid), sid)
            pipe.execute()
        except RedisError as err:
            logger.warning("redis_presence_register_fail session=%s error=%s", sid, err)
            self._fallback.register_session(
                session_id=sid,
                user_id=uid,
                worker_id=worker_id,
                tier=tier,
                connected_at=connected_at,
                last_seen_at=last_seen_at,
            )

    def unregister_session(self, session_id: str) -> None:
        sid = session_id.strip()
        if not sid:
            return
        try:
            client = self._get_client()
            user_id = client.hget(self._session_key(sid), "user_id")
            pipe = client.pipeline()
            pipe.delete(self._session_key(sid))
            if user_id:
                pipe.srem(self._user_key(str(user_id)), sid)
            pipe.execute()
        except RedisError as err:
            logger.warning("redis_presence_unregister_fail session=%s error=%s", sid, err)
            self._fallback.unregister_session(sid)

    def touch_session(self, session_id: str, *, last_seen_at: str) -> None:
        sid = session_id.strip()
        if not sid:
            return
        ttl = presence_session_ttl_seconds()
        try:
            client = self._get_client()
            session_key = self._session_key(sid)
            if not client.exists(session_key):
                return
            pipe = client.pipeline()
            pipe.hset(session_key, "last_seen_at", last_seen_at)
            pipe.expire(session_key, ttl)
            pipe.execute()
        except RedisError as err:
            logger.warning("redis_presence_touch_fail session=%s error=%s", sid, err)
            self._fallback.touch_session(sid, last_seen_at=last_seen_at)

    def sessions_for_user(self, user_id: str) -> list[UserSession]:
        uid = user_id.strip()
        if not uid:
            return []
        try:
            client = self._get_client()
            session_ids = client.smembers(self._user_key(uid))
            sessions: list[UserSession] = []
            stale: list[str] = []
            for sid in session_ids:
                raw = client.hgetall(self._session_key(sid))
                if not raw:
                    stale.append(sid)
                    continue
                sessions.append(
                    UserSession(
                        session_id=sid,
                        user_id=str(raw.get("user_id", uid)),
                        worker_id=str(raw.get("worker_id", "")),
                        tier=str(raw.get("tier", "")),
                        connected_at=str(raw.get("connected_at", "")),
                        last_seen_at=str(raw.get("last_seen_at", "")),
                    )
                )
            if stale:
                client.srem(self._user_key(uid), *stale)
            return sessions
        except RedisError as err:
            logger.warning("redis_presence_read_fail user=%s error=%s", uid, err)
            return self._fallback.sessions_for_user(uid)

    def clear(self) -> None:
        self._fallback.clear()
