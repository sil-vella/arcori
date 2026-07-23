# Soft email verification

**Status**: Completed  
**Created**: 2026-07-23  
**Last Updated**: 2026-07-23

## Objective

Soft email verification for full accounts only: SMTP via existing `MAIL_*` settings, Redis verify tokens, profile `email_verified`, Account UI resend. Login is not blocked until verified. Android/iOS deep links open the app (no Flutter web verify UI).

## Implementation Steps

- [x] Alembic `users.email_verified_at` + User model + API field
- [x] `core/email` mailer + feature flag
- [x] Redis verify store; send on full register / convert
- [x] `POST /public/auth/verify-email` + resend route
- [x] Flutter profile field + Account banner / resend
- [x] Auth error codes + messages
- [x] Tests + SECURITY / env samples (sanitized SMTP placeholders)
- [x] Android/iOS deep link `/wf-template-verify-email` + custom scheme (see [DEEP_LINKS.md](../03_Base/Flutter/DEEP_LINKS.md))

## Current Progress

Soft gate + mobile deep links complete. Flutter web verify UI explicitly out of scope.

## Next Steps

- Out of scope: hard login block, password reset, change-email
- Future: browser-open referral paths (`/rl/…`) must **not** claim `/wf-template-verify-email`

## Files Modified

- `app_codebase/python_base_05/alembic/versions/009_email_verified_at.py`
- `app_codebase/python_base_05/bin/models/user.py`
- `app_codebase/python_base_05/bin/core/email/*`
- `app_codebase/python_base_05/bin/modules/auth/*`
- `app_codebase/flutter_base_06/lib/core/http/contracts/user_api_contract.dart`
- `app_codebase/flutter_base_06/lib/modules/auth/widgets/email_verify_banner.dart`
- `app_codebase/flutter_base_06/lib/modules/auth/email_verify_deep_link.dart`
- `.env.local.sample`, `.env.prod.sample`
- `Documentation/03_Base/SECURITY_SYSTEM.md`
- `Documentation/03_Base/Flutter/DEEP_LINKS.md`

## Notes

- Flag: `ARCORI_EMAIL_VERIFICATION_ENABLED` (false local sample, true prod sample).
- Guests: never mailed; `email_verified` only true when timestamp set.
- Mail URL path: `/wf-template-verify-email?token=` (App Link); API remains `POST /public/auth/verify-email`.
- Never log raw tokens or SMTP passwords.
