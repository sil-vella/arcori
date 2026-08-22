# Arcori — Game Implementation Case Study

**Status:** Complete (narrative through 2026-08-20)  
**Created:** 2026-08-09  
**Scope:** How **Arcori** was designed and built on top of the FastAPI + Postgres + Dart + Flutter product stack. This document ignores base-template systems (auth shells, drain, logging, error envelopes, presence, etc.) except where a game decision reused them.

Design SSOT remains under [`Documentation/Game_Specific/`](../Game_Specific/). Living implementation index: [`00_MASTER_PLAN.md`](00_MASTER_PLAN.md).

---

## Menu

1. [What Arcori is](#1-what-arcori-is)
2. [Starting point — product on a finished template](#2-starting-point--product-on-a-finished-template)
3. [World vocabulary (decisions that shaped everything)](#3-world-vocabulary-decisions-that-shaped-everything)
4. [Guiding implementation principles](#4-guiding-implementation-principles)
5. [Timeline overview](#5-timeline-overview)
6. [Phase A — Design docs and player journeys](#6-phase-a--design-docs-and-player-journeys)
7. [Phase B — Catalog data home and hot-reload](#7-phase-b--catalog-data-home-and-hot-reload)
8. [Phase C — Velora, Trove, Standings (where live stats live)](#8-phase-c--velora-trove-standings-where-live-stats-live)
9. [Phase D — Avari identity and Profile](#9-phase-d--avari-identity-and-profile)
10. [Phase E — Play Hub (match setting Stage 1)](#10-phase-e--play-hub-match-setting-stage-1)
11. [Phase F — Match hot state (Dart room SSOT)](#11-phase-f--match-hot-state-dart-room-ssot)
12. [Phase G — Practice Match v1 and offline routing](#12-phase-g--practice-match-v1-and-offline-routing)
13. [Phase H — Practice stub gameplay](#13-phase-h--practice-stub-gameplay)
14. [Phase I — Player profile schema and AI seed](#14-phase-i--player-profile-schema-and-ai-seed)
15. [Phase J — Online matchmaking (Quick Start + Special Event)](#15-phase-j--online-matchmaking-quick-start--special-event)
15b. [Friend Match / invite](#15b-friend-match--invite)
16. [Architecture snapshot (game)](#16-architecture-snapshot-game)
17. [What is live today vs next](#17-what-is-live-today-vs-next)
18. [Major decisions and why](#18-major-decisions-and-why)
19. [Lessons](#19-lessons)
20. [Related docs](#20-related-docs)

---

## 1. What Arcori is

**In plain terms:**  
Arcori is a multiplayer slam / flip collectible game set in **Velora**. Players are **Avari** — people who walk beside circular Arcori pieces. Matches are short (2–4 seats, two rounds). Progress comes from **Mastery** on circulating designs and, eventually, **minting** closed generations into a personal **Trove**. Practice is free and AI-only; random multiplayer costs Gold Caps.

**Technically (game slice):**  
A product monorepo where game features live as modules on three runtimes:

| Layer | Game role |
|-------|-----------|
| **FastAPI (`python_base_05`)** | Catalog JSON SSOT, standings, Avari profile tables, AI sample for matchmaking, durable rewards later |
| **Dart (`dart_bkend_base_02`)** | Live online match room + matchmaking lobbies over authuser WS |
| **Flutter (`flutter_base_06`)** | Play pipeline, Velora browse, Avari Profile, local practice, lobby UI, match surface mirror |

Gameplay truth for **online** matches is Dart in-memory. Catalog definitions stay on FastAPI disk. Player durable progress lives in Postgres. Practice never leaves the Flutter client.

---

## 2. Starting point — product on a finished template

**Human-friendly:**  
We did not invent networking, auth, modules, or Docker for Arcori. The base template already answered “how do features register?” and “how do clients talk to servers?” Game work began by putting **world docs, catalog files, and product flows** on that house — then wiring modules one decision at a time.

**What “base vs game” means in this case study:**

| Treat as given (not narrated here) | Built as Arcori product |
|------------------------------------|-------------------------|
| Module registry, contracts, auth tiers | Catalog, Velora, Standings, Avari |
| Shared error envelope / WS client | Play hub, match hot state, matchmaking |
| Guest/auth accounts, notifications shell | Mastery ≠ ownership, Trove, economy fields |
| Compose / wfrun / Postgres / Redis | Practice offline + online AI fill |

Initial git markers for game work sit after template install (`13aea23` Initial commit), then a sequence of “pre … impl” commits for catalog → standings → Avari → play → hot state → practice → quick/special matchmaking.

---

## 3. World vocabulary (decisions that shaped everything)

These names are product decisions, not cosmetic labels. They drove schemas, screens, and APIs.

| Term | Meaning | Why it matters |
|------|---------|----------------|
| **Velora** | The world Avari explore | World browse surface — not “World Collection” |
| **Arcori** | Circular designs / pieces | Catalog entities; circulating vs closed |
| **Avari** | Player identity | Profile voice; titles stack *above* identity |
| **Master** | Competitive title | Earned via mastery / standing |
| **Legacy Owner** | Preservation title | Earned when a mint enters Trove |
| **Generation Creator** | Historical title | Named on a preserved generation |
| **Mastery** | Progress on a circulating design | **Not ownership** |
| **Trove** | Personal vault of **minted closed** Arcori only | Sink destination; empty until closures |
| **Museum** | World factual history of closed gens | Not live stats; not personal Trove |
| **Chronicle** | Mythology | What cannot be proven |
| **Slammer** | Tool used to slam / flip | Starter permanent; rechargeable variants later |
| **Gold Fragments / Caps** | Economy | 4 Fragments = 1 Cap; random MP costs 1 Cap |
| **Caller** | Match initiator (`callerUserId`) | Arena / lobby authority (not “host/steward”) |
| **Arena** | Match place (`arenaId`) | Backgrounds / FX for the whole match |
| **Launch regions** | ASH / EVG / LFR / MWB / AMB (+ **RBY** Realm Beyond, no standing) | Politics + lore in Region Catalog; standing −2…+2, not a collect lock |

**Mastery vs ownership (the hinge decision):**  
Early drafts talked about “Collection” as owned cards. Product clarified: circulating designs grant **play/mastery access** only. **Trove** is reserved for mints that left circulation. That single clarification split tables (`player_design_access` vs `player_trove`), UI (Velora vs Trove), and Match Summary wording (“mastery changes,” not “you own Tiger”).

---

## 4. Guiding implementation principles

### 4.1 Design docs first, then modules

Game_Specific drafts (GDD, Tech Spec, Content Bible, World Bible) plus active plans under `01_Active_Plans/` are the product SSOT. Code forks `example_module` patterns; it does not invent parallel room or id systems.

### 4.2 Three truths, three homes

| Truth | Owner | Lifetime |
|-------|-------|----------|
| Design definitions (stats, art paths, lore) | FastAPI catalog disk | Mutable via file edit; hot-reload for browse |
| Live match snapshot | Dart `MatchStore` (online) or Flutter local (practice) | Per match; freeze catalog once at init |
| Durable player progress | Postgres Avari tables | Forever; written post-match later |

### 4.3 One match room SSOT for all online types

Practice, Quick Start, Special Event, and Invite all eventually share the **same** in-match room (`matchId` === room id). Type-specific logic branches in matchmaking / packs / post-match — not in a second room system.

### 4.4 Lean seats, not Player class stubs in hot state

In-match seats carry `userId`, `seatIndex`, `kind`, `score`, `connected`, `arcoriIds[]`, `slammerId`. Rank, titles, and economy stay pre/post. IDs are only `userId` ↔ `connectionId` (core WS) — no third player id.

### 4.5 Full wire snapshots

Intents are small; broadcasts replace the whole `MatchSnapshot` with a `version`. Tiny seat counts make patches unnecessary; reconnect and late join reuse the same apply path.

### 4.6 Optimistic presentation, authoritative rules

Flutter may start slam animations immediately. Scores, flips, round advance, and rewards come only from the match authority (Dart online / local rules later for practice).

---

## 5. Timeline overview

Approximate product arc (2026), reconstructed from docs, commits, and chat history:

| When | Milestone |
|------|-----------|
| ~Jul 20 | Game_Specific drafts + player journey plans (first-time, returning, Home, core match loop) |
| Jul 20–23 | Align docs; place catalog JSON under Python `modules/catalog/data/`; art under `assets/images/arcori` |
| Jul 24 | Catalog loading decision (on-demand HTTP, not WS+SharedPrefs); restore docs if deleted; Velora/Trove/Standings naming |
| Jul 24–25 | Catalog hot-reload APIs + media; Velora Flutter browse; Standings module + Detail tab |
| Jul 26 | Avari title hierarchy in docs; Avari Profile screen/API; Play Hub Stage 1 + Match Flow chart |
| Aug 5 | Match hot-state design (caller, arena, seats, freeze); Dart match module + Flutter mirror |
| Aug 5–8 | Practice scaffold → **offline-only** practice correction; embedded AI pool |
| Aug 9 | Practice stub auto loop; player profile schema + 500 AI seed; Quick/Event matchmaking → match room |
| Aug 20 | Friend Match invite: contacts + instant notification Accept → 2-seat lobby → same match room SSOT |

Git “pre … impl” sequence on this repo:

```text
catalog → standings → avari profile → play module → hot state
  → practice v1 → practice AI selection → quick/special WS rooms
  → friend match invite
```

---

## 6. Phase A — Design docs and player journeys

**What we did:**  
Aligned Caps / draft material into four Game_Specific markdown files and captured end-to-end player flows as active plans (not yet all implemented in UI).

**Human-friendly:**  
Before coding match screens, we wrote down who the player is in the world, what Home feels like, and what happens the first night vs every return visit. That prevented “inventory app” language from leaking into Velora.

**Flows captured:**

| Plan | Intent |
|------|--------|
| [first-time-player-flow.md](first-time-player-flow.md) | Splash → Kin/Genesis → starter **access** → guided practice → intros → Home |
| [returning-player-startup-flow.md](returning-player-startup-flow.md) | Auto login → sync → overnight → notification queue → Home |
| [home-and-play-hub-flow.md](home-and-play-hub-flow.md) | Home composition; sink **Trove • PLAY • Market**; Play Hub modes |
| [core-match-loop.md](core-match-loop.md) | Play → matchmaking → match → celebration → Match Summary → exits |

**Technical notes:**  
Starter grant is **10 circulating design access + permanent starter slammer**, not Trove mints. Guided practice is AI-only with no economy. Match Summary must eventually show mastery, Gold Fragments, Rank XP, missions, cache, and possible mint → Trove.

**Status:** Specs remain active; Home sink and onboarding UI are still future work. Play exists as drawer `/play` ahead of the full Home hub.

---

## 7. Phase B — Catalog data home and hot-reload

**What we did:**  
Moved game JSON into the Python catalog module tree and served it over authuser HTTP with mtime/size caching so file edits appear without process restart. Mounted catalog art as public `/catalog-media/*`.

**Decision — how clients load catalog:**

| Option | Idea | Verdict |
|--------|------|---------|
| 1 | Hydrate full catalog on app init over permanent WS into SharedPrefs | Rejected |
| 2 | Fetch on Velora / Detail screens; keep in memory for the session | **Chosen** |

**Why option 2:**  
The permanent WS is a **nudge** channel (inbox-style), not a bulk pipe. ~hundreds of KB of nested JSON do not belong in SharedPrefs beside auth secrets. Lazy HTTP list/meta/theme/design matches how players actually browse.

**Technical shape:**

- Loader: `catalog_loader.py` — per-file `(mtime_ns, size)` cache; `CATALOG_DATA_ROOT` override for tests  
- Paths: `series/{series_slug}/{theme_slug}.json`; art `/{series_slug}/{theme_slug}/{internalId}.webp`  
- Authuser GETs: `/authuser/catalog/meta|index|theme|design` (exact-match router; ids via query)  
- Client payloads omit `artworkPrompt`  
- Later for matches: `POST /service/catalog/designs` batch by ids (fail-closed)

**Human-friendly:**  
Editors drop JSON and WebP on disk; the API notices; Velora shows new Arcori without redeploying the whole server. Match servers ask for a batch of designs once when a room starts, then lock those numbers for the game.

Plan: [catalog-hot-reload.md](catalog-hot-reload.md).

---

## 8. Phase C — Velora, Trove, Standings (where live stats live)

**Problem:**  
Docs said Museum was history. There was no clear place for “who is racing this design right now?”

**Naming journey (from chat):**

1. Dual entry into one **Arcori Detail** SSOT (world + personal) — good.  
2. “World Collection” → renamed **Velora** (the world).  
3. Personal “Collection” → not generic inventory: first candidate **Trove**, then refined: **Trove = minted closed only**. Circulating progress is **Mastery**, not ownership.

**Surfaces:**

| Surface | Role |
|---------|------|
| **Velora** | Browse circulating (and world) content → Arcori Detail |
| **Arcori Detail** | SSOT page; tabs **Details \| Standings** (My Mastery deferred) |
| **Standings** | Live community race: fill, leader window, ranks |
| **Trove** | Minted closed Arcori only (sink) |
| **Museum** | Closed generation archive (world), not personal |

**Transport decision:**  
HTTP on Standings tab enter. Optional later WS invalidation (`standings_changed`) while Detail is open — **not** per-flip streaming. Standings are community state, not animation ticks.

**Technical:**  
New Postgres module `standings/` (`design_standings`, `design_standings_ranks`) separate from catalog JSON. Seed/clear via wfrun for Tiger Genesis. Flutter `lib/modules/velora/` for theme browse + Detail.

**Human-friendly:**  
You walk Velora to discover Tiger. On Tiger’s page you see the live race. Your bag of mints (Trove) only fills when a generation closes and you earn the mint — until then you only grow Mastery.

Plan: [arcori-standings-surface.md](arcori-standings-surface.md).

---

## 9. Phase D — Avari identity and Profile

**What we did:**  
Named players **Avari** across GDD / World Bible / Content Bible / Tech Spec, with stacked titles. Split product **Avari Profile** (`/avari`) from account auth (`/account`). Shared avatar URL between Account upload and Avari/drawer header.

**Title hierarchy:**

```text
Avari (identity)
  → Master (competitive)
  → Legacy Owner (preservation / mint)
  → Generation Creator (historical attribution)
```

**Technical:**  
Python `modules/avari/` + Flutter `modules/avari/`; drawer chrome `_DrawerAvariHeader`. First API returned stubs; later wired to Postgres profile tables (Phase I).

**Human-friendly:**  
Account is “sign in and photo.” Avari is “who you are in Velora” — Rank, Kin, titles, mastery summary — spoken in world language.

Plans: [avari-profile.md](avari-profile.md), lore in Game_Specific docs.

---

## 10. Phase E — Play Hub (match setting Stage 1)

**What we did:**  
Built the Flutter **play** module as the pipeline shell: same screen starts and ends; type select is a centered modal; phases stubbed until later stages filled them.

**Phases:**

```text
idle → selectingType → typeSetup → inMatch → postMatch → idle
```

**Match types (codes):**

| Code | Label | Eventually |
|------|-------|------------|
| `practice` | Practice | Flutter-only |
| `quickStart` | Quick Start | Dart matchmaking |
| `specialEvent` | Special Event | Dart matchmaking (+ subtype later) |
| `invite` | Friend Match | Invite WS (private lobby) |

**Why Stage 1 first:**  
User direction: plan core flow only; leave per-type logic, real gameplay, and post-match for later. Start and end on Play so navigation debt stays low.

**Technical:**  
`MatchFlowNotifier`, `AppPaths.play`, drawer entry, smoke tests. Flowchart moved under top-level **Match Flow** (`charts/match_flow/`) because the pipeline spans Flutter + Dart + FastAPI, not Flutter alone.

Plan: [match-setting-core-flow.md](match-setting-core-flow.md).

---

## 11. Phase F — Match hot state (Dart room SSOT)

**Design conversations locked:**

1. **Dart owns online match truth; Flutter mirrors; FastAPI finalizes later.**  
2. Predictive animations yes; predictive scores no.  
3. **Full snapshots** on the wire.  
4. Lean **seats**, not rich Player stubs.  
5. `arcoriIds[]` + `slammerId` per seat; `arenaId` + **`callerUserId`** on the snapshot.  
6. Match type is an **object** (code + subtype / event fields), not a bare string.  
7. Catalog stats for physics: Dart calls FastAPI **service** batch at match init and **freezes** per match — no mid-match reload.

**Channels (authuser WS):**  
`match/create`, `join`, `leave`, `end`, `action`, broadcast `match/state`.

**Catalog freeze rule:**

```text
Catalog SSOT = FastAPI disk
Match physics SSOT = Dart per-match freeze (once at init)
Never reload catalog mid-match
```

**Technical:**  
Dart `modules/match/` (store, service, `MatchCatalogClient`, action packs). Flutter mirror via `registerMatchState`. Module-owned catalog HTTP client (keeps core free of match imports). Charts: match-setting + match-state.

**Human-friendly:**  
Everyone in the room sees the same table because one server room is the referee. When balance numbers change on disk tomorrow, games already in progress keep yesterday’s numbers until they end.

Plan: [match-hot-state.md](match-hot-state.md).

---

## 12. Phase G — Practice Match v1 and offline routing

**First attempt:**  
Practice scaffold used Dart match create/end like online — useful for proving packs, wrong for product.

**Correction (product lock):**  
Practice is **completely offline**. After mode select:

```text
Practice → loadout → 1 human + 2 AI → local MatchSnapshot → (stub) end → postMatch → idle
Online types → WS path (matchmaking / invite)
```

**AI pool decision:**  
DB had 500 AI players for online fill. For practice: **embed 10 fixed `userId`s in Flutter** (`practice_ai_pool.dart`), sampled once from the seed JSON at implement time. Each practice match randomly picks **2**. No API/DB fetch on the practice path. Seat payload stays lean (in-match fields only).

**Why:**  
Practice must work without network and without spending Gold Caps. Embedding a tiny pool keeps the client honest about “offline.” Online matchmaking still samples AI from Postgres.

**Type / subtype idea (for later packs):**  
Core actions shared; subtypes (e.g. specialEvent `royal-battle`) register extra action packs. Practice has no subtype for now.

Plans: [practice-match-v1.md](practice-match-v1.md) (routing superseded), [practice-offline-routing.md](practice-offline-routing.md).

---

## 13. Phase H — Practice stub gameplay

**What we did:**  
Auto-run a full practice match with **stub slams only** — no weighted flip physics yet.

```text
Round 1: seat0, seat1, seat2 each slam once
Round 2: same
→ localEnd → postMatch stub → idle
```

Fixed turn order (human first); ~200ms step delay (0 in tests). Surface is readout-only (no manual Slam/End).

**Why stub the whole loop first:**  
Proves Play → inMatch → postMatch → idle, UI dismiss, and notifier sequencing before investing in slam math and AI brains.

Plan: [practice-stub-gameplay.md](practice-stub-gameplay.md).

---

## 14. Phase I — Player profile schema and AI seed

**What we did:**  
Derived a complete logical **user document** from GDD + Tech Spec + onboarding, then split auth `users` from game tables. Seeded test Avari `admin@reignofplay.com` via Alembic. Fed **500 AI players** through a wfrun automation script.

**Table split (access ≠ mastery ≠ trove):**

| Table | Role |
|-------|------|
| `users` | Auth only |
| `avari_profiles` | Rank/XP, economy, stats, titles, onboarding, daily, prefs |
| `player_kin` | Genesis Kin customization |
| `player_design_access` | Circulating play/mastery access (ids) |
| `player_mastery` | Points per design/generation |
| `player_slammers` | Owned slammer instances + charges |
| `player_trove` | Minted closed Arcori only |

**Catalog vs DB (confirmed):**  
Design JSON stays files. Player tables store **ids and progress flags**, not full design blobs.

**AI seed:**  
`automation/backend/feed_ai_players.py` + `ai_players_500.json`. Interactive clear / replace-or-skip conflicts. Marker `ai_seed:v1`, emails `*@ai.arcori.local`. Used by online matchmaking sample API; practice uses its embedded 10-id subset only.

Plan: [player-profile-schema.md](player-profile-schema.md).

---

## 15. Phase J — Online matchmaking (Quick Start + Special Event)

**Product choice:**  
Implement Quick Start + Special Event with **shared** join-or-create lobby logic, separated by `queueKey` / game type. Leave Invite as Play stub until its own plan.

**Lobby algorithm (chosen):**

```text
find → join open lobby OR create + 5s timer
  → full(3) OR timeout → AI sample from DB
  → MatchLifecycle.startFromLobby
  → roomId = matchId, match/state → Flutter surface (stub end) → idle
```

Standing empty rooms forever was rejected in favor of **join-or-create + short timer + AI fill**, so solo players still reach a match.

**Hardening from device testing:**  
Auth / config failure must abort with a centered OK modal and clear sticky “Finding players” UI — not leave a black screen or orphan lobby modal. Lobby dismiss races (promote before mount) were closed.

**Technical:**  
Dart `modules/matchmaking/` + `MatchLifecycleContract`; FastAPI `POST /service/players/ai/sample`; Flutter lobby notifier + play gate.

Plans: [ws-matchmaking-modes.md](ws-matchmaking-modes.md); Friend Match [ws-invite-match.md](ws-invite-match.md).

---

## 15b. Friend Match / invite

**Product lock:** Host picks a contact, creates a private 2-seat lobby (no public queue, **no AI fill**). Guest gets a stored **instant** notification (`source=friend_match_invite`, `subtype=invite_v1`) with `data.response.type=reply` (Accept / Decline). Accept posts `/authuser/notifications/response`, then the Play reply listener joins the same lobby and both promote into the existing match room SSOT.

**Why notification, not a custom popup:**  
The guest may be anywhere in the app. The notification system already owns unread instant modals, WS `inbox_changed`, and reply dispatch. A parallel invite modal would skip inbox persistence and the Host pipeline.

**Why 2 seats / no AI:**  
Friend Match is a human vs human table. Quick/Event still fill with DB AI; invite must not.

**Technical:**  
Python `friend_match_invite` + contacts; Dart invite `queueKey` / no-AI timer; Flutter `registerPlayNotifications` reply listener. Instant modal uses `appRootNavigatorKey` because `NotificationHost` sits above `MaterialApp.router`.

Plan: [ws-invite-match.md](ws-invite-match.md).

---

## 16. Architecture snapshot (game)

```text
┌──────────────── Flutter ────────────────┐
│  Play (MatchFlow)                       │
│    practice ──► local MatchSnapshot     │
│    quick/event ► matchmaking lobby UI   │
│    invite ────► contacts + notification │
│                 → 2-seat lobby → room   │
│  Velora / Arcori Detail / Standings tab │
│  Avari Profile                          │
└───────────────┬─────────────────────────┘
                │ authuser HTTP / WS
┌───────────────┴── Dart ─────────────────┐
│  matchmaking (queues, 5s, promote)      │
│  match MatchStore + RoomRegistry        │
│  freeze via MatchCatalogClient          │
└───────────────┬─────────────────────────┘
                │ X-Service-Key HTTP
┌───────────────┴── FastAPI ──────────────┐
│  catalog JSON + /catalog-media          │
│  standings tables                       │
│  avari / access / mastery / trove       │
│  AI sample for online fill              │
└─────────────────────────────────────────┘
```

**Module map (game-facing):**

| Stack | Modules |
|-------|---------|
| Python | `catalog`, `standings`, `avari`, players AI sample, `friend_match_invite`, `contacts` |
| Dart | `match`, `matchmaking` |
| Flutter | `play`, `match`, `matchmaking`, `velora`, `avari`, notifications reply listener |

---

## 17. What is live today vs next

### Done (playable / browsable stubs)

- Velora catalog browse + Arcori Detail + Standings tab (seeded)  
- Avari Profile read (persisted for seeded users)  
- Play hub type select  
- Offline practice: loadout → 3 seats → auto stub 2×3 slams → idle  
- Online Quick Start / Special Event: lobby → AI fill → match room → stub end → idle  
- Friend Match: contacts invite → instant notification Accept → 2-seat lobby → match room → stub end  
- 500 AI players + admin test Avari in local DB  

### Next (ordered by master plan)

1. **Weighted slam / real turn logic / random first player** (practice + online)  
2. Celebration + Match Summary + FastAPI durable rewards  
3. Home sink Trove • PLAY • Market; first-time / returning flows  
4. My Mastery tab; Trove UI; economy writers from matches  

---

## 18. Major decisions and why

| Decision | Reason (human) | Reason (technical) |
|----------|----------------|--------------------|
| Mastery ≠ ownership; Trove = mints only | Collectible fantasy without claiming you “own” every design you touch | Separate tables and APIs; PLAY uses access, not trove |
| Velora name for world browse | World identity first-class | Route `/velora`; not nested under inventory |
| Catalog on disk + hot-reload | Designers iterate without migrations | mtime cache; no Postgres catalog sync yet |
| On-demand HTTP catalog, not init WS hydrate | Don’t block startup or abuse nudge WS | Riverpod session memory; SharedPrefs unused for catalog |
| Standings in Postgres, not catalog JSON | Live race changes often; defs don’t | Module `standings` + seed tooling |
| HTTP for Standings, not flip-stream WS | Race updates are sparse | Optional invalidate later |
| Dart hot match for online; Flutter-only practice | Offline practice must be free and local | Two apply paths, one snapshot shape |
| Catalog freeze at match init | Fair mid-match balance | Service batch; strip prompts |
| Five launch regions; standing −2…+2 | Politics without good/evil factions; travel and collecting stay open | Region Catalog `01_regions.json`; region-to-region standings, not design IDs |
| Match Arcori pick after seats | Players do not choose loadout online; hostility pairs more often | `04_selection_weights.json` + `POST /service/catalog/select_arcori`; pool = that seat’s circulating `player_design_access` only (weighted, else random in-pool; never global catalog) |
| Online stub turn stages before end | Prove seat order / round / slam event without physics | Dart `MatchStubLoop` after `startFromLobby`: 2×N stub slams (`lastEvent` includes `slammerId`); Flutter waits for `ended` |
| Full snapshots | Tiny state; reconnect safety | `version` + replace |
| Caller (not host/steward) | Table-feel product voice | `callerUserId` on snapshot |
| Join-or-create + 5s + AI fill | Solo players still play | Shared matchmaking for quick/event |
| Friend Match via notification reply | Guest can accept from any screen; invite persists if app was backgrounded | `create_for_user` instant + `data.response` reply; no parallel invite modal |
| Invite = 2 humans, no AI | Friend Match is a human table | Separate invite queueKey; cancel if second human never arrives |
| Embed 10 practice AI ids | True offline | No practice → DB dependency |
| Action packs by type/subtype | Events can add rules later | Core pack + registry; practice no subtype |

---

## 19. Lessons

1. **Name the world before naming the screens.** “Collection” fought the fantasy until Velora / Trove / Mastery landed.  
2. **Spec journeys early; implement the thin spine first.** Play phases and stub matches unlocked multiplayer wiring without slam physics.  
3. **Separate “definition,” “live,” and “durable.”** Mixing them forces either mid-match balance bugs or huge snapshots.  
4. **Practice and online must diverge early.** Sharing Dart create for practice looked convenient and violated the free/offline promise.  
5. **Failure UX is part of matchmaking.** Sticky lobbies after auth failure feel like game bugs; abort to idle + OK modal.  
6. **Docs get deleted; chat memory is not a backup.** Restoring Game_Specific + plans from transcripts once taught us to keep the active plan index alive.  
7. **AI pools are two products.** 500 DB AIs for online fairness; 10 embedded ids for offline honesty.

---

## 20. Related docs

### Design SSOT

- [Arcori Game Design Document](../Game_Specific/Arcori_Game_Design_Document_v0.4.md)  
- [Arcori Technical Specification](../Game_Specific/Arcori_Technical_Specification_v0.4.md)  
- [Arcori Content Bible](../Game_Specific/Arcori_Content_Bible_v0.4.md)  
- [Velora World Bible](../Game_Specific/Velora_World_Bible_v0.5.md)  

### Active plans (implementation)

- [00_MASTER_PLAN.md](00_MASTER_PLAN.md)  
- [match-setting-core-flow.md](match-setting-core-flow.md)  
- [match-hot-state.md](match-hot-state.md)  
- [practice-offline-routing.md](practice-offline-routing.md)  
- [practice-stub-gameplay.md](practice-stub-gameplay.md)  
- [ws-matchmaking-modes.md](ws-matchmaking-modes.md)  
- [ws-invite-match.md](ws-invite-match.md)  
- [stub-match-arcori-selection.md](stub-match-arcori-selection.md)  
- [catalog-hot-reload.md](catalog-hot-reload.md)  
- [arcori-standings-surface.md](arcori-standings-surface.md)  
- [avari-profile.md](avari-profile.md)  
- [player-profile-schema.md](player-profile-schema.md)  
- [core-match-loop.md](core-match-loop.md)  
- [home-and-play-hub-flow.md](home-and-play-hub-flow.md)  
- [first-time-player-flow.md](first-time-player-flow.md)  
- [returning-player-startup-flow.md](returning-player-startup-flow.md)  

### Charts

- [Match setting flow](../02_FlowCharts/charts/match_flow/match-setting-flow.html)  
- [Match state flow](../02_FlowCharts/charts/dart_backend/state/match-state-flow.html)  
- [Catalog hot-reload flow](../02_FlowCharts/charts/base/catalog-hot-reload-flow.html)  

---

*End of case study narrative (game implementation through Friend Match live, 2026-08-20).*
