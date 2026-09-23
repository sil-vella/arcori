# Master Plan

**Status:** Living index  
**Created:** 2026-07-20  
**Last Updated:** 2026-09-19

Index of active implementation plans. Detail lives in the linked files; Game_Specific docs remain design SSOT for content/model.

**Next app build:** Post-match P0 leftovers (celebration/mastery anims + achievements env) — [core-match-loop.md](core-match-loop.md). Daily Cache claim shipped — [daily-goals.md](daily-goals.md).

**Narrative:** [03_CASE_STUDY.md](03_CASE_STUDY.md) — full game implementation case study (design → matchmaking; template infra out of scope).

## Task Manager (Arcori board)

The `arcori` label is **project-wide**. Do **not** create one board task per app-build plan.

| Board task | Use for |
|------------|---------|
| **App Dev** (single card, task `32`) | All player-app micro-builds as **checklists** (and notes). Reuse this card forever. |
| **Ideas** (task `18`) | Unstructured notes — **do not edit** unless asked |
| **Template / install** | Living ops checklist |
| Other Ops cards | Marketing, dashboard revenue, cron — not the game app |

### App Dev checklist (mirror of app plans)

Done:

- [x] Catalog hot-reload + Velora browse
- [x] Avari Profile
- [x] Player profile schema + 500 AI seed
- [x] Play hub + match type select
- [x] Match hot state (Dart room SSOT + Flutter mirror)
- [x] Practice offline routing + stub gameplay
- [x] Quick Start / Special Event matchmaking (AI fill → match room → stub end)
- [x] Play failure OK modal + lobby/match dismiss hardening
- [x] Invite / Friend Match WS — [ws-invite-match.md](ws-invite-match.md)
- [x] Stub match Arcori selection (Python weights + Dart startFromLobby) — [stub-match-arcori-selection.md](stub-match-arcori-selection.md)
- [x] Stub match turn stages (2 rounds × slam, Dart auto loop) — [stub-match-turn-stages.md](stub-match-turn-stages.md)
- [x] Catalog expansion (75 nostalgia / music / TV Arcori in Genesis) — [pioneers-catalog-expansion.md](pioneers-catalog-expansion.md)
- [x] Foundations series (40 themes × 4 designs, `SER003`) — [foundations-catalog-import.md](foundations-catalog-import.md)
- [x] Civilizations series (20 themes, 94 designs, `SER004`) — [civilizations-catalog-import.md](civilizations-catalog-import.md)
- [x] Player slam input (5s turns, swipe + motion → speed/trajectory) — [player-slam-input.md](player-slam-input.md)
- [x] Arcori slam impact (stack flip + spring motion) — [arcori-slam-impact.md](arcori-slam-impact.md)
- [x] 2D slam physics (Forge2D collisions + `outcome.sim` replay) — [2d-slam-physics.md](2d-slam-physics.md)
- [x] **Random first player** — [random-first-player.md](random-first-player.md)
- [x] **3D slam physics** (thin-cylinder xyzq; replaces Forge2D) — [3d-slam-physics.md](3d-slam-physics.md)
- [x] **Slam aim + Game Controls** (exclusive accel/touch; aim miss footprint) — [slam-aim-game-controls.md](slam-aim-game-controls.md)
- [x] **Inventory slammer + disc face** (owned slammers, circulating Arcori on Avari, catalog art on discs) — [inventory-slammer-and-disc-art.md](inventory-slammer-and-disc-art.md)
- [x] **Match arena from Arcori regions** (Quick Start / Invite background + Gatherer) — [match-arena-from-arcori.md](match-arena-from-arcori.md)
- [x] **Arena mural locked to stack POV** (rest 1:1 crop, contain on zoom-out, opaque under stack) — [arena-pov-zoom.md](arena-pov-zoom.md)
- [x] **Post-match modal shell** (hold snapshot; Done / Play New; Rematch stub; finalize stub) — [core-match-loop.md](core-match-loop.md)
- [x] **Rematch (invite-style)** — `create_rematch` + series `{root}_{NNN}` matchIds; same prior AI when no other humans — [core-match-loop.md](core-match-loop.md)
- [x] **Gold Arcori economy** — rename Cap→Gold Arcori; fee 2 fragments; +1 fragment/flip; signup 20; finalize writers — [core-match-loop.md](core-match-loop.md)
- [x] **Mastery match writers** (own: 0→−1 / 1→0 / 2→+2; other flipped: 0→0 / 1→+1 / 2→+2) — [mastery.md](mastery.md)
- [x] ~~**P1** Rank XP~~ — cancelled; **Mastery Value** replaces Rank/XP (`masteryValue` + label)
- [x] **P1** Legacy / mint → Trove (website fulfill + deep-link complete) — [legacy-preserve.md](legacy-preserve.md) · [core-match-loop.md](core-match-loop.md)
- [x] **P1** Museum browse (closed Preserved/Lost + write history; profile Trove rename) — [museum-browse.md](museum-browse.md)
- [x] **Catalog DB + GEN in serial** (SSOT `catalog_designs`, import script, art_basename) — [catalog-db-gen-serial.md](catalog-db-gen-serial.md)
- [x] **Legacy echo soft reset** (30% mastery seed + random approved color) — [legacy-preserve.md](legacy-preserve.md) · [mastery.md](mastery.md)
- [x] **Closed Generations** on Avari (mastery at close + seeded amount on next gen) — [mastery.md](mastery.md) · [avari-profile.md](avari-profile.md)
- [x] **Face media: Lottie for any theme** (not Kin-only; Kin resolves via art_basename) — [catalog-db-gen-serial.md](catalog-db-gen-serial.md)

Open (ordered):

- [ ] **UI visual refactor** (gallery-first reliquary; theme tokens + hubs + match HUD) — [ui-visual-refactor.md](ui-visual-refactor.md)
- [ ] **Achievements SSOT** (code landed; env apply `016` + smoke + optional auth hydrate) — [achievements.md](achievements.md)
- [x] **Daily Goals** (JSON catalog, miss-continue, Daily Cache +2 fragments claim, media/`post_task`) — [daily-goals.md](daily-goals.md)
- [ ] **Shared unlock_type + events** (goals/tasks/achievements; match_end / special_event / leaderboard…) — [unlock-types.md](unlock-types.md)
- [ ] **P0** Celebration / mastery anims + daily / mission / cache UI — [core-match-loop.md](core-match-loop.md)
- [ ] **P1** Real winners (highest score, not all humans) — [core-match-loop.md](core-match-loop.md)
- [ ] **P1** Standings from mastery on finalize — [core-match-loop.md](core-match-loop.md) · [arcori-standings-surface.md](arcori-standings-surface.md)
- [ ] **P1** My Mastery tab + REST — [mastery.md](mastery.md)
- [x] **P1** Active-window Arcori play as SE (Preservation Chase; human hard pick + AI global windows) — [active-window-arcori-play-selection.md](active-window-arcori-play-selection.md)
- [ ] **P1** Finalize idempotency (no double-apply per `matchId`) — [core-match-loop.md](core-match-loop.md)
- [ ] **P2** Play Again (same-mode rematchmaking) — [core-match-loop.md](core-match-loop.md)
- [ ] **P2** Home / Velora / Trove exits from summary — [core-match-loop.md](core-match-loop.md)
- [ ] **P2** Durable series / results table — [core-match-loop.md](core-match-loop.md)
- [ ] **P2** Tournament / history by series — [core-match-loop.md](core-match-loop.md)
- [ ] **P2** `match_flags` into achievements — [achievements.md](achievements.md)
- [ ] **P2** Special Event fee rules — [core-match-loop.md](core-match-loop.md)
- [ ] Docs lag: case study / player-profile-schema (stub finalize wording) — [03_CASE_STUDY.md](03_CASE_STUDY.md)
- [ ] **Arcori Packs** (Gold Arcori purchase; runtime roll of circulating designs @ +5 mastery) — [arcori-packs.md](arcori-packs.md)
- [ ] **Kin creation** (wizard + Genesis claim live; production Lottie / idle anims open) — [kin-creation.md](kin-creation.md)
- [x] Home sink Trove • PLAY • Market (`hub_sink`); first-time / returning startup still open
- [ ] My Mastery tab (Trove screen holds mints + closed gens; circulating Arcori on profile)
- [x] Slammer charge spend + Market Rim (buy 4GA/20; top-up 4GA/+100; −1/slam) — [slammer-recovery-and-recharge.md](slammer-recovery-and-recharge.md)
- [ ] Slammer recovery slam-stat *(future)* — [slammer-recovery-and-recharge.md](slammer-recovery-and-recharge.md)

Standings surface is live with an open tail (My Mastery) covered above.

**Board:** App Dev (`32`) checklist mirrors post-match P0–P2 gaps. **Ideas** (`18`) untouched.

## Template / ops / project-wide (own TM cards — not App Dev)

| Plan | Status | Focus |
|------|--------|--------|
| [rop01-cron-social-auto-post.md](rop01-cron-social-auto-post.md) | In Progress | Hostinger queue + cron poster FB/YT/TT |
| [dashboard-revenue-tab.md](dashboard-revenue-tab.md) | Mostly done | wfrun Revenue tab (Play / ASC / AdMob) |
| [dashboard-parallel-script-runs.md](dashboard-parallel-script-runs.md) | Completed | Same script in multiple PTY tabs (do not kill sibling) |
| [marketing-post-metrics.md](marketing-post-metrics.md) | In Progress | Marketing metrics; Ad campaigns CSV; TikTok list still open |
| [marketing-token-refresh.md](marketing-token-refresh.md) | In Progress | FB OAuth remint + auto-extend User/Page; YT/TT/AdMob refresh |
| [01_TEMPLATE_INSTALLATION.MD](01_TEMPLATE_INSTALLATION.MD) | Living | New product install, secrets, drain, TLS, RBAC, first deploy |

## Player app flows

| Plan | Status | Focus |
|------|--------|--------|
| [first-time-player-flow.md](first-time-player-flow.md) | Spec | Splash → Kin/Genesis → starter access → guided practice → intros → Home |
| [kin-creation.md](kin-creation.md) | In Progress | Customize + POST kin claim; catalog_design mirrors regular Arcori |
| [returning-player-startup-flow.md](returning-player-startup-flow.md) | Spec | Auto login → sync → overnight → notification queue → Home |
| [home-and-play-hub-flow.md](home-and-play-hub-flow.md) | In Progress | Home widgets (MV, missions, events, World News, ticker); sink deferred |
| [match-setting-core-flow.md](match-setting-core-flow.md) | Partial | Play hub + types; practice offline; quick/event/invite online |
| [match-hot-state.md](match-hot-state.md) | Done (online room SSOT) | Dart match module + Flutter mirror; used by matchmaking promote |
| [practice-offline-routing.md](practice-offline-routing.md) | Completed | Practice = Flutter-only; embedded 10 AI pool |
| [practice-stub-gameplay.md](practice-stub-gameplay.md) | Completed | Auto stub loop: 2 rounds × 3 seats → postMatch |
| [ws-matchmaking-modes.md](ws-matchmaking-modes.md) | Completed | Quick/Event lobby → AI fill → match room SSOT |
| [ws-invite-match.md](ws-invite-match.md) | Completed | Friend Match invite WS + notification reply modal |
| [stub-match-arcori-selection.md](stub-match-arcori-selection.md) | Completed | After seats: FastAPI pick via `04_selection_weights.json` |
| [stub-match-turn-stages.md](stub-match-turn-stages.md) | Completed | Online Dart: 2×N stub slams then end; practice lastEvent aligned |
| [player-slam-input.md](player-slam-input.md) | Completed | 5s turns + swipe/motion → speed/trajectory |
| [arcori-slam-impact.md](arcori-slam-impact.md) | Completed | Stack flip + spring; attrs + `hitTarget`/`powerBracket` band → `effectivePower` |
| [2d-slam-physics.md](2d-slam-physics.md) | Completed | Forge2D side-view sim; collisions; `outcome.sim` timeline replay |
| [3d-slam-physics.md](3d-slam-physics.md) | Completed | Pure-Dart 3D thin-cylinder; `xyzq` poses; Matrix4 replay |
| [slam-aim-game-controls.md](slam-aim-game-controls.md) | Completed | Game Controls + aim marker; exclusive accel/touch; footprint miss |
| [inventory-slammer-and-disc-art.md](inventory-slammer-and-disc-art.md) | Completed | Owned slammers; circulating Arcori on Avari; catalog face on discs |
| [match-arena-from-arcori.md](match-arena-from-arcori.md) | Completed | QS/Invite: region arena + seatless Gatherer on `table.pieces` |
| [arena-pov-zoom.md](arena-pov-zoom.md) | Completed | Arena mural shares stack camera; rest is 1:1 crop (no upscale); contain on zoom-out; opaque under stack |
| [random-first-player.md](random-first-player.md) | Completed | Random `firstSeatIndex` at match start; wrap order every round |
| [practice-match-v1.md](practice-match-v1.md) | Superseded routing | Loadout + local practice; Dart packs dormant for practice |
| [core-match-loop.md](core-match-loop.md) | In Progress | Spine live; P0–P2 remaining gaps tracked |
| [legacy-preserve.md](legacy-preserve.md) | In Progress | Checkout + fulfill + proximity live; echo color/seed + Closed Generations done; play-select follow-on |
| [museum-browse.md](museum-browse.md) | Completed | World Museum from `museum_generations`; profile Museum→Trove |
| [catalog-db-gen-serial.md](catalog-db-gen-serial.md) | Completed | GEN in serial; catalog_designs DB SSOT; wfrun import; Lottie art_basename |
| [arcori-packs.md](arcori-packs.md) | Spec / backlog | Gold Arcori packs → runtime roll of circulating designs @ +5 mastery |
| [active-window-arcori-play-selection.md](active-window-arcori-play-selection.md) | Completed (v1 SE) | Preservation Chase SE: human hard pick from open windows; AI from live global open-window roster |
| [achievements.md](achievements.md) | In Progress | JSON SSOT + finalize unlocks + Flutter list/celebration; Alembic 016 apply open |
| [unlock-types.md](unlock-types.md) | Spec | Shared unlock_type + event dispatch across goals/tasks/achievements |
| [special-event-achievements.md](special-event-achievements.md) | In Progress | Per-event flips / roster clear → same celebrate + View pipeline |
| [special-events.md](special-events.md) | In Progress | JSON-driven match rules, arena/media, multi-match progress |
| [mastery.md](mastery.md) | Writers + echo seed live | Own/other finalize; Mastery Value; Closed Generations; My Mastery tab open |
| [arcori-standings-surface.md](arcori-standings-surface.md) | Partial | Standings + Detail tab; My Mastery still open |
| [catalog-hot-reload.md](catalog-hot-reload.md) | Done | Catalog JSON mtime cache, authuser APIs, Flutter Velora |
| [pioneers-catalog-expansion.md](pioneers-catalog-expansion.md) | Completed | 75 new Genesis Arcori (Nostalgia / Music / Television); Pioneers stays original 10 |
| [avari-profile.md](avari-profile.md) | Done | Avari Profile `/avari` + Trove + Closed Generations |
| [player-profile-schema.md](player-profile-schema.md) | Done | Auth + Avari tables, admin testuser seed |
| [ui-visual-refactor.md](ui-visual-refactor.md) | In Progress | Gallery-first reliquary: theme tokens, hubs, match HUD chrome |

## Design references

- [Arcori Game Design Document](../Game_Specific/Arcori_Game_Design_Document_v0.4.md)
- [Arcori Technical Specification](../Game_Specific/Arcori_Technical_Specification_v0.4.md)
- [Arcori Content Bible](../Game_Specific/Arcori_Content_Bible_v0.4.md)
- [Velora World Bible](../Game_Specific/Velora_World_Bible_v0.5.md)
