"""Shared demo/room subscribe, unsubscribe, and broadcast logic."""

from __future__ import annotations

from core.state.state_registry import room_broadcaster, room_registry
from core.ws.contracts.ws_message_contract import WsClientMessage, WsConnectionContext

DEFAULT_DEMO_ROOM_ID = "demo"


def handle_demo_room_message(ctx: WsConnectionContext, msg: WsClientMessage) -> dict | None:
    room_id = str(msg.payload.get("room_id", "")).strip() or DEFAULT_DEMO_ROOM_ID

    if msg.msg_type == "subscribe":
        room_registry.subscribe(room_id, ctx.connection_id, user_id=ctx.user_id)
        room_broadcaster.broadcast_to_room(
            room_id,
            channel="demo/room",
            msg_type="event",
            payload={
                "event": "member_joined",
                "room_id": room_id,
                "user_id": ctx.user_id,
            },
            exclude_connection_id=ctx.connection_id,
        )
        return {
            "type": "subscribed",
            "channel": "demo/room",
            "payload": {"room_id": room_id},
        }

    if msg.msg_type == "unsubscribe":
        room_registry.unsubscribe(room_id, ctx.connection_id)
        room_broadcaster.broadcast_to_room(
            room_id,
            channel="demo/room",
            msg_type="event",
            payload={
                "event": "member_left",
                "room_id": room_id,
                "user_id": ctx.user_id,
            },
            exclude_connection_id=ctx.connection_id,
        )
        return {
            "type": "unsubscribed",
            "channel": "demo/room",
            "payload": {"room_id": room_id},
        }

    if msg.msg_type == "event":
        text = str(msg.payload.get("text", ""))
        room_broadcaster.broadcast_to_room(
            room_id,
            channel="demo/room",
            msg_type="event",
            payload={
                "event": "room_message",
                "room_id": room_id,
                "user_id": ctx.user_id,
                "text": text,
            },
        )
        return {
            "type": "event",
            "channel": "demo/room",
            "payload": {
                "event": "room_message",
                "room_id": room_id,
                "user_id": ctx.user_id,
                "text": text,
            },
        }

    return None
