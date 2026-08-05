# Match State Flow — plain English guide

This chart shows **create → freeze catalog → broadcast full snapshot → end/leave** on the Dart game server.

## Concepts

| Piece | Role |
|-------|------|
| **match/create** | Practice stub: human caller + AI seat; freezes catalog via FastAPI service. |
| **MatchRuntime.catalogById** | Private freeze — not on the wire. |
| **Full snapshot** | Every broadcast replaces client mirror when `version` is newer. |
| **callerUserId / arenaId** | Who called the match; where it is played. |
| **RoomRegistry** | `connectionId` ↔ room (`matchId`) + `userId`. |

## Step-through

1. Client authenticates on Dart `ws/authuser`.
2. `match/create` → Dart batch-fetches designs → stores freeze → returns + broadcasts snapshot (`phase: playing`).
3. `match/end` (caller) → `phase: ended` + `result`.
4. `match/leave` unsubscribes; empty room may end the match.

## Copy-paste examples

```bash
# Service catalog batch (internal)
curl -s -X POST http://127.0.0.1:8000/service/catalog/designs \
  -H 'Content-Type: application/json' \
  -H 'X-Service-Key: $SERVICE_KEY' \
  -d '{"ids":["SLM-STR-GEN001-0001","ANM-TIG-GEN001-0001"]}'
```

```bash
cd app_codebase/dart_bkend_base_02
dart test test/match_store_test.dart test/match_service_test.dart
```

## Related

- [match-hot-state.md](../../../01_Active_Plans/match-hot-state.md)
- [DART_STATE_SYSTEM.md](../../../03_Base/DART_STATE_SYSTEM.md)
- [match-setting-flow](../../match_flow/match-setting-flow.html)
- [catalog-hot-reload.md](../../../01_Active_Plans/catalog-hot-reload.md)
