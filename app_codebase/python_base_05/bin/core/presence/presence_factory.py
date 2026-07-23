"""Build the active presence store implementation."""

from __future__ import annotations

from core.presence.contracts.presence_store_contract import PresenceStoreContract
from core.presence.in_memory_presence_store import InMemoryPresenceStore
from core.presence.presence_config import presence_enabled
from core.presence.redis_presence_store import RedisPresenceStore


def build_presence_store() -> PresenceStoreContract:
    if presence_enabled():
        return RedisPresenceStore()
    return InMemoryPresenceStore()
