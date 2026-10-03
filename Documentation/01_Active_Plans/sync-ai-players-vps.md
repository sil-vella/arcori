# Sync AI players to VPS

**Status:** Completed  
**Created:** 2026-09-30  
**Last Updated:** 2026-09-30

## Objective

Ship a wfrun **prod** runner that replaces AI practice opponents on the VPS Postgres + Kin upload files, without touching human users or other production data.

## Steps / Tasks

- [x] `automation/production/sync_ai_players_vps.py` (AI-only DELETE + COPY, Kin media rsync)
- [x] Source DB via `AI_SYNC_SOURCE_DATABASE_URL` / `.env.local` (never `.env.prod` DB URL)
- [x] Document in `wfrun.md` + `.env.prod.sample`

## Current Progress

Script ready. Operator: feed AI locally, then run prod sync.

## Next Steps

1. Ensure local `feed_ai_players` has written DB + `.tmp/ai_feed_uploads`
2. `wfrun` prod → `sync_ai_players_vps.py` (optional `--dry-run` first)

## Files Modified

- `automation/production/sync_ai_players_vps.py` (new)
- `.env.prod.sample`
- `Documentation/00_System_Wide/wfrun.md`
- `Documentation/01_Active_Plans/00_MASTER_PLAN.md`
- `Documentation/01_Active_Plans/sync-ai-players-vps.md` (this file)

## Notes

- AI identity: `*@arcoriaiplayer.app` OR `avari_profiles.notes = ai_seed:v1`
- Media stems use `art_basename` (GEN-stripped) under `data/uploads/kin/{players,designs}`
- Rsync does **not** `--delete` the whole uploads tree — only AI stems are written; obsolete AI stems are removed by name
