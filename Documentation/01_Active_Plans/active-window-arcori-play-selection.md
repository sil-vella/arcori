# Active-window Arcori play selection

**Status:** Completed (v1 SE)  
**Created:** 2026-09-15  
**Last Updated:** 2026-09-18

Related: [legacy-preserve.md](legacy-preserve.md) · [special-events.md](special-events.md) · [stub-match-arcori-selection.md](stub-match-arcori-selection.md) · [core-match-loop.md](core-match-loop.md) · [avari-profile.md](avari-profile.md)

## Objective

Let humans **hard-pick** one circulating Arcori from their open Legacy **preservation windows** (`first_offer` / `leader_window`) before queueing a dedicated Special Event. AI fill uses the **live global open-window roster** (not AI personal access).

## Product rules (shipped)

1. **Mode = Special Event only** — `evt_active_window_v1` (“Preservation Chase”), `arcori.source: active_windows`. Not QS/invite.
2. **Human chooses** exactly one design from `access ∩ open windows` (circulating filter at select). Hard lock for that match via `arcoriIds` on `matchmaking/find`.
3. **Eligibility:** empty personal window pool → client blocks join; server returns empty candidates. Progress is **1/1** with `allow_replay_after_complete` (quota = reward threshold only; no extra reward beyond normal mastery — stay joinable after complete).
4. **Server validates** `preferredId` in `select_for_seats` (must be ∈ eligible circulating candidates); invalid → weighted re-pick.
5. **Seat uniqueness** unchanged (first claim wins).
6. **AI fill:** pool = live `list_open_preservation_windows`; empty global set → fall back to AI normal access (starters), then stub.

## Implementation (done)

- [x] `ARCORI_SOURCE_ACTIVE_WINDOWS` + event JSON
- [x] `build_candidate_ids_for_user`: human ∩ windows; AI = global windows
- [x] `select_for_seats` `preferredId` honor/reject
- [x] Dart `startFromLobby` always selects for SE seats with `preferredId` (validate + uniqueness)
- [x] Flutter: window picker from `preservationWindows`; find payload includes `arcoriIds`
- [x] Unit tests: candidates, preferredId, empty pool

## Out of scope (later)

- QS/invite pins, persisted favorites, practice mode
- Changing Legacy window phases / proximity notifs
- Disabling AI for this event

## Files

- `special_events.json` / `special_events_types.py` / `special_events_service.py`
- `catalog_select.py` · Dart `match_service.dart`
- Flutter `active_window_picker_modal.dart` · `play_screen.dart` · `play_notifier.dart`
- Tests: `test_active_windows_candidates.py` · preferredId cases in `test_catalog_select.py`
