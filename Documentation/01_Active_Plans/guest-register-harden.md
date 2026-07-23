# Guest register harden

**Status**: Completed  
**Created**: 2026-07-23  
**Last Updated**: 2026-07-23

## Objective

Keep public guest registration (Flutter bootstrap) but tighten abuse surface: require `@arcori.arcori` for guests and a dedicated Redis IP bucket. No app attestation in this work.

## Implementation Steps

- [x] Guest email domain rule in `auth_service.register`
- [x] Reject full register with guest suffix
- [x] `guest_register` Redis bucket (default 5 / 3600s)
- [x] Env keys in samples + sync to real env files
- [x] Unit tests
- [x] SECURITY_SYSTEM + this plan

## Current Progress

Complete. Attestation explicitly deferred.

## Next Steps

- Optional later: Play Integrity / App Attest when shipping internal Play/Apple builds

## Files Modified

- `app_codebase/python_base_05/bin/modules/auth/auth_service.py`
- `app_codebase/python_base_05/bin/core/rate_limit/rate_limit_config.py`
- `app_codebase/python_base_05/bin/core/rate_limit/guest_register.py`
- `app_codebase/python_base_05/tests/modules/auth/test_guest_and_email_verify.py`
- `.env.local.sample`, `.env.prod.sample`
- `Documentation/03_Base/SECURITY_SYSTEM.md`

## Notes

- Still subject to global + `/public/auth` middleware IP limits.
- Log: `rate_limit_hit bucket=guest_register …`
