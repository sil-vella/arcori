# Notification system — plain English guide

This chart shows how **arcori** stores notifications in Postgres, pushes inbox updates over WebSocket, and renders **navigate** / **reply** modals in Flutter.

## What is it?

Notifications are **in-app only** (no OS push). Two scopes:

| Scope | Table | Meaning |
|-------|-------|---------|
| **User** | `user_notifications` | One row per user (module-created) |
| **Global** | `global_notifications` | One campaign row for everyone; per-user read in `global_notification_reads` |

**Delivery** (`type`): `instant` auto-modals when unread; `inbox` is list-only.

**Semantics** (`category` + `subtype`): what the message *is* and which rules apply (allowed screens, reply keys, modal priority, 700ms gap). Both required on create; must be registered in the subtype registry.

## In-modal sequence

`NotificationHost` opens **one** modal session via `showNotificationModalSequence(pending)`.

Inside `notification_modal.dart`:

1. Show first pending unread instant
2. User acts or dismisses → mark shown / mark read
3. Wait **700ms** (subtype may override)
4. Show next message in the **same shell** until list is done

Inbox list still uses batch `GET`; only modal presentation is sequential.

## Subtype registry

Modules register `(source, category, subtype)` specs at bootstrap (Python + Flutter):

| Rule | Example |
|------|---------|
| `allowed_screens` | Navigate buttons must use these slugs |
| `reply_option_keys` | Reply keys must match exactly |
| `modal_priority` | Lower = shown first in pending list |
| `inter_modal_delay_ms` | Gap before next message (default 700) |

Unknown subtypes are rejected on `create_for_user` and global sync.

## Response framework (`data.response`)

| Type | What JSON sets | What code does |
|------|----------------|----------------|
| **`navigate`** | Button labels + `screen` or `to_path` | Client: resolve slug → `Nav.push`, optional mark-read |
| **`reply`** | Option `key` + `label` | Client: POST response → module handler → mark-read |

Legacy `responses[]` (no `data.response`): single OK, dismiss → mark-read.

## Screen slugs (Flutter)

`"screen": "example_module"` → modules register via **`NotificationScreenSink`** beside routes. Subtype spec may further restrict which screens are allowed.

## Global campaigns (ops)

```bash
wfrun   # → automation/backend/sync_global_notifications.py
```

Seed: `automation/backend/files/global_notifications.json` — requires `category` + `subtype`.

## Try it locally

1. `wfrun` → docker up
2. `wfrun` → sync global notifications (fresh DB)
3. Flutter dev login → **Example module** → **Send demo notifications**
4. Or open **Notifications** inbox

Example reply handler branches on `subtype = example_reply_demo`, keys `accept` / `decline`.

## Key endpoints

| Method | Path | Role |
|--------|------|------|
| `POST` | `/service/notifications/create` | Create user row (`category` + `subtype` required) |
| `GET` | `/authuser/notifications/messages` | User inbox |
| `GET` | `/authuser/notifications/globals` | Global campaigns |
| `POST` | `/authuser/notifications/response` | Reply option dispatch |

## While app is open

Insert → `inbox_changed` WS → Flutter refetch → `NotificationHost` → `showNotificationModalSequence`.

## Related docs

- [NOTIFICATION_SYSTEM.md](../../../03_Base/NOTIFICATION_SYSTEM.md) — full schema, registry, tests
- [WS_SYSTEM.md](../../../03_Base/WS_SYSTEM.md)
- [MODAL_SYSTEM.md](../../../03_Base/Flutter/MODAL_SYSTEM.md)
