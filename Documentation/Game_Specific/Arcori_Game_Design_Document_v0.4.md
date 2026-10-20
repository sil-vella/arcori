# Arcori Game Design Document

Working Draft v0.4  
**Last aligned:** 2026-10-14 (Slammer Legacy shipped: sweet-spot mastery; Arcori close → Velora; Museum/Trove slammer-only)

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

### Arcori — Mastery → Generation close → Velora

World State: Active/Closed. When mastery reaches `closureMilestone`, that generation closes immediately and the next generation is seeded with `echo_mastery_seed` (30%). There is **no** Arcori preserve offer, leader window, physical mint, Museum row, or Trove row.

Until closure the player holds **Mastery** on a circulating design — not ownership. Closed generations stay readable in **Velora** (browse + Arcori Detail), including Master / Generation Creator where attributed.

Catalog series share that closure loop; they differ in how soon a generation can close:

| Series | Role | preservationRequirement | closureMilestone |
|--------|------|-------------------------|------------------|
| **Creation** | Primordial Light / Dark (4 designs) | 50 | 100 |
| **Genesis** | Main launch catalog | 500 | 1000 |
| **Pioneers** | Small companion series (ten seed designs) | 100 | 200 |
| **Foundations** | Civilization / society themes (160 designs) | 250 | 500 |
| **Civilizations** | Civic institutions (94 designs) | 300 | 600 |

**Why Pioneers exists:** the lower preservation and closure numbers so those generations can **close and appear in Velora history earlier** than Genesis — first world-history records while Genesis generations are still filling. It is not a second art drop for its own sake, and it is not a physical-mint track.

**Foundations** sits between them (250 / 500) with forty society themes (Hearth, Shelter, … Unity), four designs each (`SER003`). **Civilizations** (`SER004`) is the next civic layer (Capital, Districts, Guilds, … Dynasties), 94 designs across twenty themes, at 300 / 600.

Arcori physical mint into Trove is retired. Preserve / mint runs on **slammers** only. See [slammer-legacy.md](../01_Active_Plans/slammer-legacy.md).

### Slammers — Sweet-spot Mastery → Preserve → Legacy Mint

```text
Acquire → Learn (online sweet spot) → Slammer Mastery → Preserve race → Mint or Lost
```

Online slams add **slammer mastery** as `flipCount × preferenceFit` (server-only sweet spot). Practice grants nothing and does not apply the fit bonus. The player sees mastery gained as a number only — never the hit target or power band.

When mastery reaches catalog `legacy.preservationRequirement` (Genesis starters: 750), the existing preserve phases run (first offer → leader window → minted or lost at `closureMilestone`, default 1000). Mint seals the Legacy snapshot (owner, mastery, matches, slams, flips, best slam, Legacy ID). The digital slammer stays playable. Echo grants the next generation on `player_slammers` at `floor(closed × 0.30)`, min 1, cap preserve−1.

**Museum** and **Trove** list slammer generations only (minted / lost / in-progress Legacy). Closed Arcori are Velora history, not those sinks.

Attunement / richer Legacy Eligible gates remain a follow-on on top of this shipped bar.

## Economy

**Gold Fragments** and **Gold Arcori** are wallet currency only (not catalog designs, not circulating, not playable).

- **4 Gold Fragments = 1 Gold Arcori** (auto-convert).
- Online match fee: **2 Gold Fragments** (special events may differ later).
- Each flip the player scores: **+1 Gold Fragment**.
- Practice is free (no fee, no fragment rewards).
- New Avari profiles (guest or regular) start with **20 Gold Arcori**.
- Market purchases and Slammer recharge use Gold Arcori.

## Slammers

Starter balanced slammer. Rechargeable variants with Impact, Precision, Control, Recovery and Spread (public feel). Sweet spot (`hitTarget` / `powerBracket`) is server-only and drives slammer mastery + flip strength online. See [Slammers — Sweet-spot Mastery](#slammers--sweet-spot-mastery--preserve--legacy-mint) and [slammer-legacy.md](../01_Active_Plans/slammer-legacy.md).

## Progression

| Track | Meaning |
|-------|---------|
| Mastery Value | Avari progression (replaces Rank / XP) |
| Mastery → Design | Progress on a **circulating** Arcori (not owned); path toward **Master** |
| Generations → World | Arcori close at milestone → Velora history (**Master** / **Generation Creator**); not a physical Arcori trophy |
| Slammer Legacy | Sweet-spot mastery → preserve race → optional physical mint; Museum/Trove are slammer-only; echo seeds next gen at 30% |

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
| **Velora** | World browse — circulating Arcori plus **closed** generations (archive path); lands and Realm Beyond |
| **Trove** | Personal **Legacy Slammers** (minted / in-progress preserve tools). Slammer-only |
| **Arcori Detail** | SSOT page for a design; submenu **Standings** + **My Mastery** |
| **Standings** | Live community race (top mastery, generation fill, leader window) |
| **My Mastery** | Your mastery on this design — not ownership while circulating |
| **Museum** | World-facing history of closed **slammer** generations (minted / lost). Closed Arcori live in Velora |
| **Profile** | Avari identity, Mastery Value, earned titles (Master / Generation Creator); Trove for Legacy Slammers |

**Startup (returning):** Splash → Notifications → News → Daily Missions → Home.  
**Bottom sink:** Trove • PLAY • Market.  
**PLAY** picks from circulating mastery-accessible designs.  
**Velora** is a first-class world entry from Home (and related surfaces), not a mode under Trove.

**Arcori Detail entry defaults:** Velora → Standings; Match Summary mastery change → My Mastery. A minted slammer opens its Legacy record from Trove.
