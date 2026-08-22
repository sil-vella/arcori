# WS Invite Match (Friend Match)

**Status:** Completed  
**Created:** 2026-08-09  
**Last Updated:** 2026-08-20

Related: [ws-matchmaking-modes.md](ws-matchmaking-modes.md) · [match-hot-state.md](match-hot-state.md) · [match-setting-core-flow.md](match-setting-core-flow.md) · [00_MASTER_PLAN.md](00_MASTER_PLAN.md) · [NOTIFICATION_SYSTEM.md](../03_Base/NOTIFICATION_SYSTEM.md)

## Objective

Replace the Play **invite** stub with a real Friend Match path that lands in the existing **match room SSOT**, using the shared **notification system** for the guest Accept/Decline popup.

## Live behavior

Host: Play → invite setup (contacts) → `POST /authuser/friend_match_invites/create` → private lobby (2 seats, no AI fill).

Guest: `create_for_user` instant + `data.response.type=reply` → WS `inbox_changed` → `NotificationHost` modal → Accept posts `/authuser/notifications/response` → play reply listener joins lobby → both promote into match room SSOT → stub end.

Verified 2026-08-20 on two Android devices (`global.log`: modal shown, accept, lobby 2/2, promote, `inMatch`).

## Scope locks

- Reuse match room SSOT from [match-hot-state.md](match-hot-state.md); do not invent a parallel room id
- Guest popup is the notification system (`type=instant`, `data.response` reply) — no parallel invite modal
- Auth gate + OK modal pattern from [ws-matchmaking-modes.md](ws-matchmaking-modes.md)
- Practice stays Flutter-only; quickStart/specialEvent stay queue-based matchmaking with AI fill
- Invite lobby is **2 humans**, **no AI fill**
- No durable rewards / Match Summary in this plan

## Implementation steps

- [x] Product: friends list + private invite lobby (no public queue); 2 seats; no AI fill
- [x] Python invite module: create/resolve + notification subtype/reply handler
- [x] Dart matchmaking: invite queueKey, no-AI fill, resolve invited user
- [x] Flutter: invite setup UI + guest join via notification reply listener
- [x] Instant modal uses GoRouter root navigator (`appRootNavigatorKey`) — Host context has no Navigator
- [x] Device verify (host create → guest modal Accept → both in match)
- [x] Master + related plans marked done

## Current Progress

Shipped. Guest modal failed at first because `NotificationHost` sat above `MaterialApp.router` and used its own context (no `Navigator`/`Theme`). Fixed via `appRootNavigatorKey`; Accept follow-up is `registerNotificationReplyListener` (not a special-case in `notification_modal.dart`). Core Host/navigator patch also ported to the template repo.

## Next Steps

None on this plan. Next app build: **weighted slam / real turns / random first player** (master plan).

## Files Modified

- `app_codebase/python_base_05/bin/modules/friend_match_invite/**`
- `app_codebase/python_base_05/bin/modules/contacts/**`
- `app_codebase/dart_bkend_base_02/bin/modules/matchmaking/matchmaking_service.dart`
- `app_codebase/flutter_base_06/lib/modules/play/**`
- `app_codebase/flutter_base_06/lib/modules/notifications/notification_host.dart`
- `app_codebase/flutter_base_06/lib/core/navigation/app_router.dart`
- `app_codebase/flutter_base_06/lib/modules/play/register_play_notifications.dart`
- `Documentation/03_Base/NOTIFICATION_SYSTEM.md`

## Notes

Do not invent a parallel invite popup. Guest UX is the notification system (`instant` + `reply`). Play-specific follow-up belongs in `registerNotificationReplyListener`, not in `notification_modal.dart`.

## Case study

Updated [03_CASE_STUDY.md](03_CASE_STUDY.md) — Friend Match live path, notification-reply decision, architecture snapshot.

## Task Manager

App Dev (task `32`) checklist: Invite / Friend Match WS — check off; next open line is weighted slam.
