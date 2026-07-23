"""Register demo WebSocket channels on all tiers."""

from core.state.room.room_demo_handler import handle_demo_room_message
from core.ws.contracts.register_channel_contract import ApplicationChannelSink
from modules.ws.demo_ws_service import handle_demo_echo, handle_system


def register_demo_ws_channels(channels: ApplicationChannelSink) -> None:
    for register in (
        channels.public_channel,
        channels.authuser_channel,
        channels.service_channel,
    ):
        register("system", handle_system)
        register("demo/echo", handle_demo_echo)
        register("demo/room", handle_demo_room_message)
