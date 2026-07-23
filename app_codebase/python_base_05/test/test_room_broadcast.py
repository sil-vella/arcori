from core.state.connection_registry import ConnectionRegistry
from core.state.room.broadcast_hub import BroadcastHub
from core.state.room.room_registry import RoomRegistry


def test_room_broadcast_excludes_sender() -> None:
    connections = ConnectionRegistry()
    membership = RoomRegistry()
    hub = BroadcastHub(connections=connections, membership=membership)

    sent: dict[str, list[str]] = {}

    def make_send(key: str):
        def _send(frame: str) -> None:
            sent.setdefault(key, []).append(frame)

        return _send

    connections.register("a", make_send("a"))
    connections.register("b", make_send("b"))
    membership.subscribe("demo", "a", user_id="user-a")
    membership.subscribe("demo", "b", user_id="user-b")

    hub.broadcast_to_room(
        "demo",
        channel="demo/room",
        msg_type="event",
        payload={"event": "room_message", "text": "hi"},
        exclude_connection_id="a",
    )

    assert "a" not in sent
    assert sent["b"]


def test_on_connection_closed_removes_membership() -> None:
    membership = RoomRegistry()
    membership.subscribe("demo", "conn-1", user_id="u1")
    membership.on_connection_closed("conn-1")
    assert membership.connection_ids("demo") == set()
