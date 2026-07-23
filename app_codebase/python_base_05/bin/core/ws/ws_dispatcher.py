"""WebSocket connection loop: auth handshake, channel routing, JSON envelopes."""

from __future__ import annotations

import asyncio
import logging
import random
import time
from typing import Any

from fastapi import WebSocket
from starlette.websockets import WebSocketDisconnect

from core.auth.verify_access import verify_access_or_raise
from core.auth.verify_service_key import verify_service_key_or_raise
from core.errors.app_error import AppError
from core.errors.error_codes import INTERNAL_ERROR, NOT_FOUND, UNAUTHORIZED
from core.state.room.room_lifecycle import (
    on_ws_authuser_connected,
    on_ws_authuser_message,
    on_ws_connection_closed,
)
from core.state.state_registry import connection_registry
from core.utils.dev_logger import customlog
from core.ws.contracts.ws_message_contract import WsClientMessage, WsConnectionContext
from core.ws.response.ws_response import encode_error, encode_ok, parse_incoming
from core.ws.service.channel_registry import get_channel_handler

logger = logging.getLogger(__name__)

LOGGING_SWITCH = False

_TIER_PUBLIC = "public"
_TIER_AUTHUSER = "authuser"
_TIER_SERVICE = "service"

_connection_seq = 0


def _next_connection_id() -> str:
    global _connection_seq
    _connection_seq += 1
    return f"conn-{time.time_ns()}-{random.randint(0, 1 << 20)}-{_connection_seq}"


def _handle_authuser_auth(ctx: WsConnectionContext, data: dict[str, Any]) -> tuple[bool, str | None]:
    payload = data.get("payload")
    if not isinstance(payload, dict):
        payload = {}
    token = str(payload.get("access_token", "")).strip()
    try:
        auth_ctx = verify_access_or_raise(token or None)
    except AppError as err:
        logger.info("ws_error tier=authuser code=%s reason=auth", err.code)
        return False, err.to_ws_frame()
    ctx.user_id = auth_ctx.user_id
    ctx.claims = auth_ctx.claims
    ctx.authenticated = True
    return True, encode_ok({"type": "connected", "channel": "system", "user_id": ctx.user_id})


def _handle_service_auth(ctx: WsConnectionContext, data: dict[str, Any]) -> tuple[bool, str | None]:
    payload = data.get("payload")
    if not isinstance(payload, dict):
        payload = {}
    provided = str(payload.get("service_key", "")).strip()
    try:
        verify_service_key_or_raise(provided or None)
    except AppError as err:
        logger.info("ws_error tier=service code=%s reason=auth", err.code)
        return False, err.to_ws_frame()
    ctx.authenticated = True
    return True, encode_ok({"type": "connected", "channel": "system"})


async def run_ws_connection(websocket: WebSocket, *, tier: str) -> None:
    """FastAPI WebSocket entry — auth handshake then channel dispatch loop."""
    await websocket.accept()
    connection_id = _next_connection_id()
    ctx = WsConnectionContext(tier=tier, connection_id=connection_id)
    needs_auth = tier in (_TIER_AUTHUSER, _TIER_SERVICE)

    def register_connection() -> None:
        async def send_frame(frame: str) -> None:
            await websocket.send_text(frame)

        def schedule_send(frame: str) -> None:
            asyncio.create_task(send_frame(frame))

        connection_registry.register(connection_id, schedule_send)

    def unregister_connection() -> None:
        connection_registry.unregister(connection_id)

    if tier == _TIER_PUBLIC:
        ctx.authenticated = True
        register_connection()
        if LOGGING_SWITCH:
            customlog(f"ws connected tier={tier} connection_id={connection_id}")
        await websocket.send_text(encode_ok({"type": "connected", "channel": "system"}))

    try:
        while True:
            try:
                text = await websocket.receive_text()
            except WebSocketDisconnect:
                break

            data, parse_err = parse_incoming(text)
            if parse_err is not None:
                if LOGGING_SWITCH:
                    customlog(
                        f"ws parse error tier={tier} connection_id={connection_id} "
                        f"code={parse_err['code']}"
                    )
                logger.info(
                    "ws_error tier=%s code=%s reason=parse",
                    tier,
                    parse_err["code"],
                )
                await websocket.send_text(
                    encode_error(code=parse_err["code"], message=parse_err["message"])
                )
                continue
            assert data is not None

            msg = WsClientMessage.from_data(data)
            if msg is None:
                logger.info("ws_error tier=%s code=invalid_message reason=shape", tier)
                await websocket.send_text(
                    encode_error(code="invalid_message", message="type and channel required")
                )
                continue

            if needs_auth and not ctx.authenticated:
                if msg.msg_type != "auth":
                    err = AppError(UNAUTHORIZED, message="First message must be type auth")
                    logger.info("ws_error tier=%s code=%s reason=auth_order", tier, err.code)
                    await websocket.send_text(err.to_ws_frame())
                    await websocket.close()
                    return
                if tier == _TIER_AUTHUSER:
                    ok, frame = _handle_authuser_auth(ctx, data)
                else:
                    ok, frame = _handle_service_auth(ctx, data)
                if frame:
                    await websocket.send_text(frame)
                if not ok:
                    if LOGGING_SWITCH:
                        customlog(
                            f"ws auth failed tier={tier} connection_id={connection_id}"
                        )
                    await websocket.close()
                    return
                register_connection()
                if tier == _TIER_AUTHUSER and ctx.user_id:
                    on_ws_authuser_connected(ctx.user_id, connection_id)
                if LOGGING_SWITCH:
                    customlog(
                        f"ws authenticated tier={tier} connection_id={connection_id} "
                        f"user_id={ctx.user_id or ''}"
                    )
                continue

            if tier == _TIER_AUTHUSER and ctx.authenticated:
                on_ws_authuser_message(connection_id)

            handler = get_channel_handler(tier, msg.channel)
            if handler is None:
                err = AppError(NOT_FOUND, message=f"No handler for channel {msg.channel}")
                logger.info(
                    "ws_error tier=%s channel=%s code=%s reason=unknown_channel",
                    tier,
                    msg.channel,
                    err.code,
                )
                await websocket.send_text(err.to_ws_frame())
                continue

            try:
                result = handler(ctx, msg)
            except AppError as err:
                logger.info(
                    "ws_error tier=%s channel=%s code=%s reason=handler",
                    tier,
                    msg.channel,
                    err.code,
                )
                await websocket.send_text(err.to_ws_frame())
                if err.spec.fatal_ws:
                    await websocket.close()
                    return
                continue
            except Exception:
                if LOGGING_SWITCH:
                    customlog(
                        f"ws handler error tier={tier} channel={msg.channel} "
                        f"connection_id={connection_id}"
                    )
                logger.exception("ws_handler_error tier=%s channel=%s", tier, msg.channel)
                err = AppError(INTERNAL_ERROR, message="Handler failed")
                await websocket.send_text(err.to_ws_frame())
                continue

            if result is not None:
                await websocket.send_text(encode_ok(result))
    except WebSocketDisconnect:
        pass
    finally:
        if LOGGING_SWITCH:
            customlog(f"ws closed tier={tier} connection_id={connection_id}")
        on_ws_connection_closed(connection_id)
        unregister_connection()
