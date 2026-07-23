# Notification System Implementation Plan

**Status**: Completed  
**Created**: 2026-06-30  
**Last Updated**: 2026-06-30

## Objective

Implement post-auth FastAPI WebSocket auto-connect with resume recovery, and a core notifications module with user + global messages (`instant` and `inbox` types), persistence, read/delete, and module-authored creates via service tier.

## Implementation Steps

- [x] Python `UserConnectionRegistry` + `InboxBroadcaster`
- [x] Flutter `AppWsCoordinator` + `AppLifecycleObserver`
- [x] Alembic `005_notifications` + seed welcome global
- [x] Python notifications module (REST + service create)
- [x] Flutter notifications module (API, notifier, host, screen)
- [x] Example module integration on record
- [x] Tests + `NOTIFICATION_SYSTEM.md`

## Files Modified

### Python
- `bin/core/state/user_connection_registry.py`
- `bin/core/ws/inbox_broadcaster.py`
- `bin/core/state/state_registry.py`
- `bin/core/ws/ws_dispatcher.py`
- `bin/models/user_notification.py`
- `bin/models/global_notification.py`
- `bin/models/global_notification_read.py`
- `bin/modules/notifications/*`
- `bin/modules/example_module/example_service.py`
- `alembic/versions/005_notifications.py`

### Flutter
- `lib/core/ws/app_ws_*`
- `lib/modules/notifications/*`
- `lib/app_init.dart`
- `lib/modules/module_registry.dart`

## Notes

- v1 uses in-memory WS fan-out per worker; Redis pub/sub deferred for multi-worker Gunicorn.
- OS push (FCM/APNs) deferred.
