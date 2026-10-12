# Arcori Game Design Document

Working Draft v0.4  
**Last aligned:** 2026-10-09 (personal Legacy is the slammer; Arcori stay world history)

## Gameplay

2–4 players. One Arcori each. Two rounds. One flip = one point. Mastery deltas use seat flip count (see Progression). Practice mode is AI only with no progression (no mastery).

Players (**Avari**) select circulating designs they have **play/mastery access** to (starter unlocks, Market, etc.). That access is **not ownership**.

## Avari (player)

In Velora, players are **Avari** — those who walk beside the Arcori. They master Arcori as world history, learn a slammer as a personal tool, and may leave a Legacy by minting that slammer.

### Title hierarchy

A player can become, in order:

| Title | Kind | Meaning |
|-------|------|---------|
| **Avari** | Identity | Every player — the baseline name for who you are in Velora |
| **Master** | Competitive title | Earned through mastery / competitive standing on designs |
| **Generation Creator** | Historical title | Named when a closed Arcori generation attributes its creator |
| **Legacy** | Slammer preservation | A **Legacy Slammer** whose physical mint sealed a frozen personal record |

These stack as achievements and standing — **Avari** remains identity; the rest are earned titles above it.

**Note:** Match **Achievements** (declarative catalog unlocks — first win, streaks, mastery thresholds) are a separate system from this title hierarchy. See [achievements.md](../01_Active_Plans/achievements.md). Titles are not awarded via that catalog.

## Two histories

**Arcori = world history. Slammers = player history.**

Fantasy: **Master the Arcori. Learn your slammer. Leave your Legacy.**

Detail: [slammer-legacy.md](../01_Active_Plans/slammer-legacy.md).

### Arcori — Mastery → Generation → Closure → Museum

World State: Active/Closed. A generation still closes (leader window, closure milestone, echo generation, Museum snapshot, **Master**, **Generation Creator**). That loop does **not** require a physical Arcori purchase.

Until closure the player holds **Mastery** on a circulating design — not ownership. Closed generations are Museum history, for example: MUSHROOM I, Generation I, Master, highest mastery, closed date, and who created Generation II.

Catalog series share that closure loop; they differ in how soon a generation can close:

| Series | Role | preservationRequirement | closureMilestone |
|--------|------|-------------------------|------------------|
| **Creation** | Primordial Light / Dark (4 designs) | 50 | 100 |
| **Genesis** | Main launch catalog | 500 | 1000 |
| **Pioneers** | Small companion series (ten seed designs) | 100 | 200 |
| **Foundations** | Civilization / society themes (160 designs) | 250 | 500 |
| **Civilizations** | Civic institutions (94 designs) | 300 | 600 |

**Why Pioneers exists:** the lower preservation and closure numbers so those generations can **close and enter the Museum earlier** than Genesis — first world-history records while Genesis generations are still filling. It is not a second art drop for its own sake, and it is not a physical-mint track.

**Foundations** sits between them (250 / 500) with forty society themes (Hearth, Shelter, … Unity), four designs each (`SER003`). **Civilizations** (`SER004`) is the next civic layer (Capital, Districts, Guilds, … Dynasties), 94 designs across twenty themes, at 300 / 600.

The live app still offers an Arcori website mint into Trove from the previous plan. That physical offer is **not** the target. New mint work is the slammer. See [legacy-preserve.md](../01_Active_Plans/legacy-preserve.md).

### Slammers — Attunement → Slammer Mastery → Legacy → Physical Mint

```text
Acquire → Learn → Attune → Master → Legacy → Mint
```

**Mastered** means that slammer’s mastery bar is full. **Legacy Eligible** requires Mastered plus significant use (100% Attunement, full Slammer Mastery, flip and match thresholds, and optionally one Mastery challenge). Only then is **Legacy Available**.

The player may keep using it, or physically mint **that** slammer. Minting seals the Legacy record (owner, mastered date, matches, successful slams, Arcori flipped, best slam, attunement, mastery) and a unique QR / Legacy ID. The digital slammer stays playable as a **Legacy Slammer**. Later play is **Post-Legacy** and does not rewrite the sealed record.

When a **slammer generation** closes, players move to the next generation with the same mastery seed Arcori already use. The closed generation’s mastery stays. Anyone with mastery above 0 on it receives the next generation at `floor(closed × 0.30)`, at least 1, and never as high as `preservationRequirement`. Attunement does not carry. A sealed Legacy record stays on the generation that was minted.

Trove target: **My Legacy Slammers** (Minted, Mastered, or still in progress). Several slammers can each be minted.

## Economy

**Gold Fragments** and **Gold Arcori** are wallet currency only (not catalog designs, not circulating, not playable).

- **4 Gold Fragments = 1 Gold Arcori** (auto-convert).
- Online match fee: **2 Gold Fragments** (special events may differ later).
- Each flip the player scores: **+1 Gold Fragment**.
- Practice is free (no fee, no fragment rewards).
- New Avari profiles (guest or regular) start with **20 Gold Arcori**.
- Market purchases and Slammer recharge use Gold Arcori.

## Slammers

Starter balanced slammer. Rechargeable variants with Impact, Precision, Control, Recovery and Spread (catalog feel). Personal progression is separate: Attunement, then Slammer Mastery, then Legacy, then an optional physical mint. See [Slammers — Attunement](#slammers--attunement--slammer-mastery--legacy--physical-mint) above and [slammer-legacy.md](../01_Active_Plans/slammer-legacy.md).

## Progression

| Track | Meaning |
|-------|---------|
| Mastery Value | Avari progression (replaces Rank / XP) |
| Mastery → Design | Progress on a **circulating** Arcori (not owned); path toward **Master** |
| Generations → World | Closure writes Museum history (**Master** / **Generation Creator**); not a physical Arcori trophy |
| Slammer Legacy | Attunement → Slammer Mastery → Legacy → optional physical mint; digital slammer stays usable. Generation close seeds the next gen at 30% of closed mastery (same as Arcori) |

### Mastery deltas (per online match)

**Own played Arcori** (the design you brought) — **your** flips of that design; only this track applies −1:

| Your flips of that design | Mastery Δ |
|---------------------------|-----------|
| 0 | −1 |
| 1 | 0 |
| 2+ | +2 |

**Already mastered, not your seat pick** (opponent brought a design you already progress on):

| Your flips of that design | Mastery Δ |
|---------------------------|-----------|
| 0 | 0 (no deduction) |
| 1 | 0 |
| 2+ | +2 |

**Other Arcori** (no prior mastery; designs **you** flipped) — per that design’s flip count:

| Your flips of that design | Mastery Δ |
|---------------------------|-----------|
| 0 | 0 |
| 1 | +1 |
| 2+ | +2 |

Practice skips mastery. Persist on `player_mastery`; floor at 0 on write. Detail: [mastery.md](../01_Active_Plans/mastery.md).

### Selection weight (sole rarity signal)

Each design has one number: **`selectionWeight`** from **0.01** (rarest) to **10.00** (most common). There is **no** `printedRarity` tier. The same field drives match seat pick, Gatherer pick, and Mastery Value.

### Mastery Value (player aggregate → profile)

Replaces Rank / XP. Profile shows the numeric **Mastery Value** and the Fair→Priceless **label**.

```text
MasteryValue = Σ_i ( masteryPoints_i × (10.0 / selectionWeight_i) )
N            = circulating playable catalog Arcori count
               (Active; exclude SLM / KIN / slammer)
density      = MasteryValue / max(1, N)
```

- Sum every `player_mastery` row for that Avari.
- Clamp each design’s `selectionWeight` to `[0.01, 10.00]` (missing → 3.0).
- Rarer (lower weight) → higher value per point.
- **N** is global catalog size (not the player’s pool). Larger catalog → same value ranks lower.

Profile shows **label only** (backend computes). Density bands:

| Label | Density |
|-------|---------|
| Fair | `< 0.5` |
| Notable | `0.5 – < 1.5` |
| Sought | `1.5 – < 4` |
| Coveted | `4 – < 10` |
| Exquisite | `10 – < 25` |
| Priceless | `≥ 25` |

Wire: `mastery.masteryValue` + `mastery.masteryValueLabel`. Rank/XP is not used. Events keep design identity; mastery continues on the design’s active generation rules.

## Events

Events are match types with their own rules and rewards. Designs retain their identity and mastery.

## Daily Systems

Three featured missions, Daily Cache, extra mission rewards and no-miss streak bonus.

## Destinations and navigation

| Name | Role |
|------|------|
| **Velora** | World browse — five launch lands (Ashdrift Hill, Everlight Grove, Little Frost, Moonwake Bay, Amberwild) plus the Realm Beyond, and anything found there (most notably circulating Arcori) |
| **Trove** | Personal **Legacy Slammers** (mastered / minted tools). Today’s `/trove` still lists minted closed Arcori until that screen moves |
| **Arcori Detail** | SSOT page for a design; submenu **Standings** + **My Mastery** |
| **Standings** | Live community race (top mastery, generation fill, leader window) |
| **My Mastery** | Your mastery on this design — not ownership while circulating |
| **Museum** | World-facing factual history of closed Arcori generations (not the personal Trove) |
| **Profile** | Avari identity, Mastery Value, earned titles (Master / Generation Creator); Trove for Legacy Slammers |

**Startup (returning):** Splash → Notifications → News → Daily Missions → Home.  
**Bottom sink:** Trove • PLAY • Market.  
**PLAY** picks from circulating mastery-accessible designs.  
**Velora** is a first-class world entry from Home (and related surfaces), not a mode under Trove.

**Arcori Detail entry defaults:** Velora → Standings; Match Summary mastery change → My Mastery. A minted slammer opens its Legacy record from Trove.
