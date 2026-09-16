# Active-window Arcori play selection

**Status:** Spec / backlog  
**Created:** 2026-09-15  
**Last Updated:** 2026-09-15

Related: [legacy-preserve.md](legacy-preserve.md) · [stub-match-arcori-selection.md](stub-match-arcori-selection.md) · [core-match-loop.md](core-match-loop.md) · [avari-profile.md](avari-profile.md)

## Objective

Let players **choose** which circulating Arcori they bring into a match when that design is in an active Legacy **preservation window** (`first_offer` / `leader_window`), instead of relying only on weighted/random seat pick from the full access pool.

## Problem

Today online match Arcori assignment is server-side weighted (else random) over `player_design_access` — see [stub-match-arcori-selection.md](stub-match-arcori-selection.md). During a leader window, proximity notifications urge “Play now,” but the player **cannot target** the design they are racing on. That breaks the chase / pressure loop.

Profile already lists open windows under **Preservation Windows** (`preservationWindows` on Avari profile). That list is the natural source for a preferred / pinned play design.

## Open design questions (resolve at plan time)

- Prefer vs force: soft preference (bias weights) vs hard lock for next match / Play hub confirm?
- One pin only, or ordered favorites?
- Does pin apply to Quick Start, Invite, Special Event, practice — or Play hub online only?
- Interaction with uniqueness across seats (two players pin the same design)?
- UX: pick from Preservation Windows chips on profile, Play hub pre-match sheet, or both?

## Implementation Steps (not started)

- [ ] Product rules: preference vs lock; which match modes
- [ ] Persist player preference (Avari preferences JSON or dedicated column / table)
- [ ] Wire `select_arcori` (or pre-match Play UI) to honor active-window preference when design is still circulating + in access
- [ ] Flutter: select from Preservation Windows (and clear when window closes / Lost / preserved)
- [ ] Clear or invalidate pin when lifecycle leaves open window
- [ ] Tests: preferred design selected when eligible; falls back when not

## Notes

- Do **not** put Trove / Museum designs into the match pool.
- Kin / hostility / unique-id rules from existing seat selection still apply unless explicitly changed.
- **Debug:** Home **Debug match finalize** loads `assets/debug/match_finalize_sample.json` and POSTs the same `avari/match/finalize` as post-match (injects `__SELF__` → auth user id; `uniqueMatchId` timestamps each tap). Use to exercise mastery / legacy without playing a match.
