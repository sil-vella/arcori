# Refresh token rotation + revocation

**Status**: Completed  
**Created**: 2026-07-23  
**Last Updated**: 2026-07-23

## Objective

Redis-backed refresh-token rotation with reuse detection and explicit revocation on logout, convert-guest, and delete-account. Flutter persists rotated refresh tokens and calls server logout.

## Implementation Steps

- [x] `refresh_session_store` (Redis current-jti per user) + config
- [x] Rotate in `refresh_access_token`; `SET` on `_issue_token_pair`; revoke on delete/convert
- [x] `POST /public/auth/logout` + stdlib security logs
- [x] Flutter parse/persist rotated refresh; logout calls revoke API
- [x] Tests + SECURITY / PRODUCTION docs + this plan

## Notes

- Redis key: `Arcori:rt:user:{user_id}` → current refresh `jti`
- Fail-closed on Redis errors during refresh verify
- Incident greps: `refresh_rotated|refresh_reuse_detected|refresh_revoked|refresh_session_store_fail`
