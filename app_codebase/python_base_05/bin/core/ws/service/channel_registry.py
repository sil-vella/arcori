"""In-memory WebSocket channel registry (mirrors HTTP route registry)."""

from __future__ import annotations

from core.ws.contracts.register_channel_contract import ApplicationChannelSink, WsChannelHandler

_TIER_PUBLIC = "public"
_TIER_AUTHUSER = "authuser"
_TIER_SERVICE = "service"


class _ChannelRegistry(ApplicationChannelSink):
    def __init__(self) -> None:
        self._handlers: dict[str, WsChannelHandler] = {}

    def clear(self) -> None:
        self._handlers.clear()

    def _key(self, tier: str, channel: str) -> str:
        return f"{tier}:{channel}"

    def _add(self, tier: str, channel: str, handler: WsChannelHandler) -> None:
        self._handlers[self._key(tier, channel)] = handler

    def get_handler(self, tier: str, channel: str) -> WsChannelHandler | None:
        return self._handlers.get(self._key(tier, channel))

    def public_channel(self, channel: str, handler: WsChannelHandler) -> None:
        self._add(_TIER_PUBLIC, channel, handler)

    def authuser_channel(self, channel: str, handler: WsChannelHandler) -> None:
        self._add(_TIER_AUTHUSER, channel, handler)

    def service_channel(self, channel: str, handler: WsChannelHandler) -> None:
        self._add(_TIER_SERVICE, channel, handler)


_the_registry = _ChannelRegistry()
application_ws_sink: ApplicationChannelSink = _the_registry


def reset_channel_registry() -> None:
    _the_registry.clear()


def get_channel_handler(tier: str, channel: str) -> WsChannelHandler | None:
    return _the_registry.get_handler(tier, channel)
