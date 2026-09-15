# Arcori Game Design Document

Working Draft v0.4  
**Last aligned:** 2026-09-13 (Mastery Value label Fair→Priceless)

## Gameplay

2–4 players. One Arcori each. Two rounds. One flip = one point. Mastery deltas use seat flip count (see Progression). Practice mode is AI only with no progression (no mastery).

Players (**Avari**) select circulating designs they have **play/mastery access** to (starter unlocks, Market, etc.). That access is **not ownership**.

## Avari (player)

In Velora, players are **Avari** — those who walk beside the Arcori. They do not command Arcori destinies; they shape journeys through skill, perseverance, and Legacy preservation.

### Title hierarchy

A player can become, in order:

| Title | Kind | Meaning |
|-------|------|---------|
| **Avari** | Identity | Every player — the baseline name for who you are in Velora |
| **Master** | Competitive title | Earned through mastery / competitive standing on designs |
| **Legacy Owner** | Preservation achievement | Earned when a generation closes and the mint enters the player’s Trove |
| **Generation Creator** | Historical title | Attributed when a preserved/minted generation names its creator |

These stack as achievements and standing — **Avari** remains identity; the rest are earned titles above it.

**Note:** Match **Achievements** (declarative catalog unlocks — first win, streaks, mastery thresholds) are a separate system from this title hierarchy. See [achievements.md](../01_Active_Plans/achievements.md). Titles are not awarded via that catalog.

## Legacy and minting

World State: Active/Closed. Legacy State: Legacy Preserved/Legacy Lost. Immediate preservation opportunity then 30-day leader window. Auto closure at mastery cap.

When a generation **closes** and a player earns the mint (closing limit / leader–preservation rules), that Arcori leaves circulation and enters the player’s **Trove** as a **minted** piece. That mint confers **Legacy Owner** for that piece. Until then the player only holds **Mastery** on the design — not ownership.

Catalog series share that loop; they differ in how soon a generation can close:

| Series | Role | preservationRequirement | closureMilestone |
|--------|------|-------------------------|------------------|
| **Genesis** | Main launch catalog | 500 | 1000 |
| **Pioneers** | Small companion series (ten seed designs) | 100 | 200 |
| **Foundations** | Civilization / society themes (160 designs) | 250 | 500 |

**Why Pioneers exists:** the lower preservation and closure numbers so those designs can be **minted earlier** than Genesis — first Trove pieces while Genesis generations are still filling. It is not a second art drop for its own sake.

**Foundations** sits between them (250 / 500) with forty society themes (Hearth, Shelter, … Unity), four designs each (`SER003`).

## Economy

**Gold Fragments** and **Gold Arcori** are wallet currency only (not catalog designs, not circulating, not playable).

- **4 Gold Fragments = 1 Gold Arcori** (auto-convert).
- Online match fee: **2 Gold Fragments** (special events may differ later).
- Each flip the player scores: **+1 Gold Fragment**.
- Practice is free (no fee, no fragment rewards).
- New Avari profiles (guest or regular) start with **20 Gold Arcori**.
- Market purchases and Slammer recharge use Gold Arcori.

## Slammers

Starter balanced slammer. Rechargeable variants with Impact, Precision, Control, Recovery and Spread.

## Progression

| Track | Meaning |
|-------|---------|
| Mastery Value | Avari progression (replaces Rank / XP) |
| Mastery → Design | Progress on a **circulating** design (not owned); path toward **Master** |
| Generations → World | Design/world state; closure can mint into Trove (**Legacy Owner** / **Generation Creator**) |

### Mastery deltas (per online match)

**Own played Arcori** (the design you brought):

| Seat flips | Mastery Δ |
|------------|-----------|
| 0 | −1 |
| 1 | 0 |
| 2 | +2 |

**Other Arcori** (designs whose discs **you** flipped, not your own played piece) — per that design’s flip count:

| Flips on that design | Mastery Δ |
|----------------------|-----------|
| 0 | 0 |
| 1 | +1 |
| 2 | +2 |

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
| **Trove** | Personal vault of **minted closed** Arcori only (out of circulation) |
| **Arcori Detail** | SSOT page for a design; submenu **Standings** + **My Mastery** |
| **Standings** | Live community race (top mastery, generation fill, leader window) |
| **My Mastery** | Your mastery on this design — not ownership while circulating |
| **Museum** | World-facing factual history of closed generations (not the personal Trove) |
| **Profile** | Avari identity, Mastery Value, earned titles (Master / Legacy Owner / Generation Creator); links to Trove for mints |

**Startup (returning):** Splash → Notifications → News → Daily Missions → Home.  
**Bottom sink:** Trove • PLAY • Market.  
**PLAY** picks from circulating mastery-accessible designs (not Trove mints by default).  
**Velora** is a first-class world entry from Home (and related surfaces), not a mode under Trove.

**Arcori Detail entry defaults:** Velora → Standings; Match Summary mastery change → My Mastery; successful mint → Trove.
