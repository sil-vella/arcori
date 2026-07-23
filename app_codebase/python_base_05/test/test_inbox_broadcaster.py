from core.state.connection_registry import ConnectionRegistry
from core.state.user_connection_registry import UserConnectionRegistry
from core.ws.inbox_broadcaster import InboxBroadcaster


def test_user_connection_registry_register_unregister() -> None:
    registry = UserConnectionRegistry()
    registry.register("user-1", "conn-a")
    registry.register("user-1", "conn-b")
    assert registry.connection_ids_for_user("user-1") == {"conn-a", "conn-b"}
    assert registry.user_id_for_connection("conn-a") == "user-1"

    registry.unregister("conn-a")
    assert registry.connection_ids_for_user("user-1") == {"conn-b"}
    registry.unregister("conn-b")
    assert registry.connection_ids_for_user("user-1") == set()


def test_inbox_broadcaster_notifies_all_user_connections() -> None:
    connections = ConnectionRegistry()
    user_connections = UserConnectionRegistry()
    broadcaster = InboxBroadcaster(
        connections=connections,
        user_connections=user_connections,
    )

    sent: dict[str, list[str]] = {}

    def make_send(key: str):
        def _send(frame: str) -> None:
            sent.setdefault(key, []).append(frame)

        return _send

    connections.register("a", make_send("a"))
    connections.register("b", make_send("b"))
    user_connections.register("user-1", "a")
    user_connections.register("user-1", "b")

    broadcaster.notify_inbox_changed("user-1")

    assert len(sent["a"]) == 1
    assert len(sent["b"]) == 1
    assert "inbox_changed" in sent["a"][0]
    assert "notifications/inbox" in sent["a"][0]
