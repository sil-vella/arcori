# Player Profile Schema (Avari + auth)

**Status:** In Progress — schema + Alembic seed landed; API read wired to tables  
**Created:** 2026-08-09  
**Last Updated:** 2026-08-09

Related: [avari-profile.md](avari-profile.md) · [first-time-player-flow.md](first-time-player-flow.md) · [GDD](../Game_Specific/Arcori_Game_Design_Document_v0.4.md) · [Tech Spec](../Game_Specific/Arcori_Technical_Specification_v0.4.md)

## Objective

Persist the full Avari player document as Postgres tables (auth `users` + game tables), with a deterministic local test user seed.

## Complete profile example (test user)

Logical aggregate after `011_player_profile` (password hashed with `modules.auth.password_utils.hash_password` / bcrypt):

```json
{
  "id": "a0000000-0000-4000-8000-000000000001",
  "username": "admin",
  "email": "admin@reignofplay.com",
  "password_hash": "$2b$12$… (bcrypt of qepiarcori1!)",
  "is_guest": false,
  "email_verified_at": "2026-08-09T00:00:00+00:00",
  "avatar_url": null,
  "created_at": "…",
  "updated_at": "…",

  "avari": {
    "displayName": "Admin",
    "title": "Avari",
    "titles": ["Avari"],
    "rank": { "xp": 0, "level": 1, "label": null },
    "economy": { "goldFragments": 0, "goldCaps": 5 },
    "stats": { "matchesPlayed": 0, "wins": 0, "flips": 0 },
    "onboarding": {
      "completed": true,
      "kinChosen": true,
      "genesisCreated": true,
      "starterGranted": true,
      "guidedPracticeDone": true,
      "introsDone": true
    },
    "daily": {
      "loginStreak": 0,
      "lastLoginRewardAt": null,
      "cacheClaimedAt": null,
      "noMissStreak": 0
    },
    "preferences": { "notifications": { "push": true } },
    "kin": {
      "subtheme": "Entelairs",
      "style": "Chibi",
      "finish": "Standard",
      "effect": "None",
      "genesisDesignId": "KIN-SIL202607092145-GEN001-0001",
      "chosenName": "Admin",
      "customization": {}
    }
  },

  "access": [
    { "designId": "ANM-TIG-GEN001-0001", "source": "starter" },
    { "designId": "ANM-WTI-GEN001-0002", "source": "starter" },
    { "designId": "ANM-LIO-GEN001-0003", "source": "starter" },
    { "designId": "ANM-BPA-GEN001-0004", "source": "starter" },
    { "designId": "ANM-CHE-GEN001-0005", "source": "starter" },
    { "designId": "ANM-LEO-GEN001-0006", "source": "starter" },
    { "designId": "ANM-SNL-GEN001-0007", "source": "starter" },
    { "designId": "ANM-JAG-GEN001-0008", "source": "starter" },
    { "designId": "ANM-AWO-GEN001-0009", "source": "starter" },
    { "designId": "ANM-GWO-GEN001-0010", "source": "starter" }
  ],

  "mastery": [],

  "slammers": [
    {
      "designId": "SLM-STR-GEN001-0001",
      "permanent": true,
      "chargesRemaining": null,
      "source": "starter"
    }
  ],

  "trove": []
}
```

Local login: `admin@reignofplay.com` / `qepiarcori1!`

## Tables

| Table | Role |
|-------|------|
| `users` | Auth identity (unchanged columns) |
| `avari_profiles` | 1:1 Rank/XP, economy, stats, titles, onboarding, daily, prefs |
| `player_kin` | Genesis Kin customization (1:1) |
| `player_design_access` | Circulating play/mastery access (not ownership) |
| `player_mastery` | Points per `(user, design, generation)` |
| `player_slammers` | Owned slammer instances + charges |
| `player_trove` | Minted closed Arcori only |

## Implementation Steps

- [x] Document complete user document + table split
- [x] SQLAlchemy models + Alembic `011_player_profile` (+ testuser seed)
- [x] Wire `GET /authuser/avari/profile` to read persisted profile
- [ ] Match / economy writers update mastery, gold, stats
- [ ] Link `design_standings_ranks.user_id` when standings leave synthetic labels
- [ ] First-time flow writes Kin + starter grants instead of seed-only

## Current Progress

Schema migration and admin testuser seed are in tree. Avari profile GET loads from `avari_profiles` (+ kin / mastery summary) when present. Unit test for persisted shape passes. **Applied locally:** Alembic head `011_player_profile`; test user seeded and profile read verified (Admin, 5 caps, 10 access, Kin Entelairs).

## Next Steps

Run Alembic upgrade in the target env; use the test user for Flutter login smoke. Defer trove/daily writers until those systems land.

**AI seed (local/dev):** `automation/backend/feed_ai_players.py` via wfrun — loads `automation/backend/data/ai_players_500.json`. Prompts to clear existing AI players and to replace/skip email conflicts.

**Practice AI pool (Flutter offline):** a fixed sample of 10 seed `userId`s is embedded in client code (`practice_ai_pool.dart`). Practice does **not** query the DB or FastAPI for AI; each match randomly picks 2 from that list. See [practice-offline-routing.md](practice-offline-routing.md).

## Files Modified

- `Documentation/01_Active_Plans/player-profile-schema.md`
- `Documentation/01_Active_Plans/00_MASTER_PLAN.md`
- `app_codebase/python_base_05/bin/models/avari_profile.py`
- `app_codebase/python_base_05/bin/models/player_progress.py`
- `app_codebase/python_base_05/alembic/versions/011_player_profile.py`
- `app_codebase/python_base_05/alembic/env.py`
- `app_codebase/python_base_05/bin/modules/avari/avari_service.py`
- `app_codebase/python_base_05/bin/modules/avari/avari_repository.py`
- `automation/backend/feed_ai_players.py`
- `automation/backend/data/ai_players_500.json`

## Notes

- Do not store plaintext passwords in DB; seed uses bcrypt via `password_utils`.
- Access ≠ mastery ≠ trove (Tech Spec semantics preserved as separate tables).
- `users` stays auth-only; game fields live on related tables.
