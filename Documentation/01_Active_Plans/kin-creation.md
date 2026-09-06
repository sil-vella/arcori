# Kin Creation (start to finish)

**Status:** Planned — not implemented  
**Created:** 2026-09-05  
**Last Updated:** 2026-09-05

Related: [first-time-player-flow.md](first-time-player-flow.md) · [avari-profile.md](avari-profile.md) · [player-profile-schema.md](player-profile-schema.md) · [GDD](../Game_Specific/Arcori_Game_Design_Document_v0.4.md)

## Objective

Ship the **Kin creation** path end to end: a signed-in Avari with no Kin walks through lineage → customize → name, the server persists `player_kin` and a Genesis Kin Arcori, and Avari Profile shows it. One Kin per player.

This is the identity slice of first-time onboarding. Starter access, guided practice, intros, and Home remain on [first-time-player-flow.md](first-time-player-flow.md).

## Flow

```text
signed-in Avari, no player_kin
  → choose Kin subtheme (lineage)
  → customize style / finish / effect
  → choose name
  → server writes player_kin + Genesis Kin
  → onboarding_kin_chosen + onboarding_genesis_created
  → Avari Profile Kin section shows the result
```

The Kin Arcori is the player’s personal **Genesis Arcori** (in-world avatar), not the Account photo.

## Live today (do not regress)

- Tables: `player_kin` (1:1 `user_id`) + `avari_profiles.onboarding_kin_chosen` / `onboarding_genesis_created`
- `GET /authuser/avari/profile` already returns `kin` when a row exists (seeded Admin / AI players)
- Profile UI shows Kin as text (`Not claimed yet` when null)
- Catalog sample: `02_kin.json` has one Entelairs Genesis (`KIN-SIL202607092145-GEN001-0001`)
- No write API, no Flutter wizard, no Kin lineage picker catalog (Kin is missing from `00_themes_subthemes.json`)

## Implementation Steps

- [ ] Kin lineage SSOT the picker can load (catalog meta — not the single sample in `02_kin.json`)
- [ ] `POST /authuser/avari/kin` (or equivalent): validate once, insert `player_kin`, set onboarding flags; reject if Kin already exists
- [ ] Allocate `genesisDesignId` (player creator); decide catalog vs player-private storage for that design
- [ ] Flutter wizard: subtheme → customize → name → confirm; gate until Kin exists
- [ ] Avari Profile Kin section uses persisted fields (name, lineage, style/finish/effect, face if present)
- [ ] Tests: create happy path, duplicate Kin rejected, profile read after create

## Current Progress

Plan + App Dev checklist only. Schema and profile **read** already exist.

## Next Steps

Implement the write path and wizard when this checklist is picked up. Do not block Celebration / Match Summary.

## Files Modified

- (none yet — planning)

## Notes

- **Not in this plan:** 10 circulating starter access, permanent slammer grant, guided practice, Velora/Trove/Rank/Museum intros, Home sink.
- Style / finish / effect should reuse existing catalog enumerations (same fields as other Arcori).
- Artwork generation from `artworkPrompt` is a later step unless a stub face is required to finish the wizard.
- Existing seeded users already have Kin; the wizard is for new accounts (and any Avari with `kin == null`).

## Case study

`03_CASE_STUDY.md` — Kin creation called out as its own slice; first-time flow still owns the rest of onboarding.

## Task Manager

App Dev (`32`): checklist **Kin creation start to finish** — item `241` (open). Note `242`.
