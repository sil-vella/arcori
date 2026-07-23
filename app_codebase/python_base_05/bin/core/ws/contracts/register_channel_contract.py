"""Let feature modules register WebSocket channel handlers without knowing the registry."""

from __future__ import annotations

from typing import Any, Callable, Protocol

from core.ws.contracts.ws_message_contract import WsClientMessage, WsConnectionContext

WsChannelHandler = Callable[[WsConnectionContext, WsClientMessage], dict[str, Any] | None]


class ApplicationChannelSink(Protocol):
    """Register channel handlers per tier.

    **Channel** names are logical (e.g. ``demo/echo``) — do not include ``/authuser`` prefix.
    """

    def public_channel(self, channel: str, handler: WsChannelHandler) -> None: ...

    def authuser_channel(self, channel: str, handler: WsChannelHandler) -> None: ...

    def service_channel(self, channel: str, handler: WsChannelHandler) -> None: ...
