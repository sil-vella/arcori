# Marketing — token refresh scripts (per platform)

**Status**: In Progress  
**Created**: 2026-08-10  
**Last Updated**: 2026-08-31

## Objective

Keep Facebook / YouTube / TikTok (and AdMob) credentials usable without manual token paste on every expiry. Access tokens auto-refresh; rotated refresh tokens / reminted Page tokens are written back to `WFRUN_ENV_FILE`.

## Context

- **YouTube / AdMob / TikTok** refresh *access* tokens from a stored *refresh* token. `invalid_grant` means the **refresh token itself** was revoked — browser OAuth (`*_oauth_get_refresh_token.py`). Auto-renew cannot invent a new refresh token.
- **Facebook** has no refresh token. Long-lived **User** tokens are `fb_exchange_token`’d when expiry is within 14 days. **Page** tokens are reminted from `/me/accounts` whenever the User token has `pages_show_list`. Declined Page scopes (typical after Graph Explorer Ads-only login) require one browser login: `facebook_oauth_get_tokens.py`.
- Silent persist: `publish_common.persist_env_key` / `revenue_common.persist_env_key`.

## Implementation Steps

### Done
- [x] Document required env keys (FB/YT/TT in samples + dashboard doc)
- [x] YouTube / TikTok / Facebook interactive validate+OAuth runners
- [x] Shared `token_renewal.py` (FB extend + YT/TT refresh + persist)
- [x] Wire publish / metrics / dashboard playlist refresh through `token_renewal`
- [x] AdMob refresh via `revenue_common.google_oauth_access_token` (persist rotated refresh)
- [x] `ensure_platform_tokens.py` wfrun runner + preflight before Marketing publish
- [x] Cron preflight via `ensure_marketing_tokens` (alert + abort on re-auth required)
- [x] `deploy_rop01_marketing.sh` syncs YT + FB Page + FB User tokens to rop
- [x] `facebook_oauth_get_tokens.py` — local browser OAuth (Page + Ads), writes User + Page tokens
- [x] Auto-remint Page token from User `/me/accounts` inside `facebook_page_token`

### Later
- [ ] TikTok Production Live + swap client credentials when approved
- [ ] Operator re-auth after current `invalid_grant` on YT + AdMob
- [x] Run `facebook_oauth_get_tokens.py --write-env` once so Page scopes are granted (currently declined on the Ads User token)

## Current Progress

Auto-renew path is wired for YT/TT/AdMob/FB-User **and** FB Page. Local OAuth on 31 Aug 2026 granted `pages_show_list` + Ads; User + Page tokens written to `.env.local`. `ensure_marketing_tokens(facebook)` succeeds.

## Next Steps

1. Re-run `youtube_oauth_get_refresh_token.py` / `admob_oauth_get_refresh_token.py` if those still show `invalid_grant`.

## Files Modified

- `automation/marketing/token_renewal.py`
- `automation/marketing/facebook_oauth_get_tokens.py`
- `automation/marketing/facebook_validate_page_token.py`
- `automation/marketing/ensure_platform_tokens.py`
- `automation/marketing/cron_social_auto_post.py`
- `automation/wfrun_excluded_scripts.txt`
- `.env.local.sample` / `.env.prod.sample`
- `Documentation/01_Active_Plans/marketing-token-refresh.md`

## Notes

- Never log full tokens; never commit `.env.local`.
- TikTok often rotates `refresh_token` on each refresh — must persist or the next run dies.
- Google rarely rotates refresh tokens; `invalid_grant` almost always means revoked consent / password change / unused 6 months (testing apps).
- Facebook Login → Settings may need Valid OAuth Redirect URI `http://localhost:8766/callback/` (override with `FACEBOOK_OAUTH_REDIRECT_URI`). Use **localhost**, not `127.0.0.1` — Facebook requires HTTPS for every other host. That is one-time app config, not Graph Explorer token minting.
- After a successful OAuth, cron `ensure_marketing_tokens` extends the User token and remints the Page token automatically.

## Case study

n/a — ops token plumbing, no game-logic change.

## Task Manager

Ops card **Marketing token refresh** (task `45`). Open checklist: run `facebook_oauth_get_tokens.py --write-env` once.
