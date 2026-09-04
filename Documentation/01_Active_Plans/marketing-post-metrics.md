# Marketing dashboard — post metrics (FB → YT → TT)

**Status**: In Progress  
**Created**: 2026-08-14  
**Last Updated**: 2026-08-31

## Objective

Show live post metrics on Marketing, browse **all** remote platform posts (not only GUI-saved drafts), and list Facebook **Ad campaigns** with a full insights sheet download.

## Implementation Steps

- [x] Facebook: `facebook_post_metrics.py` — engagement summaries + **full** lifetime Insights (batched; partial skip on deprecated metrics) when permitted
- [x] API: `GET /api/marketing/posts/{id}/metrics/facebook` (saved drafts)
- [x] Marketing detail UI: Metrics panel + Refresh (FB)
- [x] Document `read_insights` for full FB Insights
- [x] Marketing sub-tabs: **Saved** (GUI) vs **Platform posts** (remote)
- [x] API: `GET /api/marketing/platform-posts?platform=facebook` (+ paging)
- [x] API: `GET /api/marketing/metrics/facebook?object_id=…` for remote posts
- [x] YouTube platform list (`playlistItems` on uploads) + `videos.list?part=statistics` on detail
- [x] API: `GET /api/marketing/platform-posts?platform=youtube` (+ paging)
- [x] API: `GET /api/marketing/metrics/youtube?object_id=…` + saved-post metrics route
- [x] Ad campaigns tab: list Ads Manager ads + per-row campaign insights CSV
- [x] API: `GET /api/marketing/ads` (+ paging)
- [x] API: `GET /api/marketing/ads/campaigns/{campaign_id}/insights.csv`
- [ ] TikTok platform list after `video.list` (+ re-auth)

## Current Progress

- **Saved** — drafts/publishes from the dashboard + FB/YT metrics on detail when that platform published.
- **Platform posts** — Facebook + YouTube lists (**5 per page**, platform filter + Load more). List is lightweight (no engagement/stats). Open a row → detail loads live metrics. TikTok filter returns “not wired yet” (501).
- **Ad campaigns** — Facebook Ads Manager ads (**25 per page**, Load more). List is lightweight (name, campaign, status, objective, created). Each row has **Download sheet** for that ad’s parent campaign (lifetime + daily + adset/ad + breakdowns). Uses User token (`ads_read`); optional `FACEBOOK_AD_ACCOUNT_ID`.

## Next Steps

1. TikTok platform browser + metrics after `video.list`.

## Files Modified

- `automation/marketing/facebook_post_metrics.py`
- `automation/marketing/facebook_ad_metrics.py`
- `automation/marketing/youtube_post_metrics.py`
- `automation/dashboard/serve.py`
- `automation/dashboard/static/index.html`
- `automation/dashboard/static/marketing.js`
- `automation/dashboard/static/style.css`
- `automation/wfrun_excluded_scripts.txt`
- `.env.local.sample` / `.env.prod.sample`
- `Documentation/01_Active_Plans/marketing-post-metrics.md`
- `Documentation/01_Active_Plans/00_MASTER_PLAN.md`

## Notes

- Saved list stays local JSON; Platform posts and Ad campaigns hit live APIs.
- Never log tokens. Metrics are fetched live.
- YouTube uses the same OAuth refresh credentials as publish (`YOUTUBE_*`).
- Ads list uses `FACEBOOK_USER_ACCESS_TOKEN` (`ads_read`). CSV export runs several Graph Insights calls and can take a minute.

## Case study

Skipped — dashboard ops, not game/app logic.

## Task Manager

Own Ops card **Marketing post metrics** (task `35`), not App Dev. TikTok list still open. Ad campaigns checklist added 2026-08-31.
