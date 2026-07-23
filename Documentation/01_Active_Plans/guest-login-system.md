# User Account System (Guest Login + Full Accounts)

**Status**: Completed  
**Created**: 2026-06-29  
**Last Updated**: 2026-06-29

## Objective

Persisted user accounts on FastAPI with auto guest registration on Flutter first launch, in-app Account hub (sign in / create / convert), profile display, and avatar upload for full accounts only.

---

## Account types

| Capability | Guest | Regular (full) |
|------------|-------|----------------|
| Auto sign-in on first launch | Yes | — |
| Module data keyed by `user_id` | Yes | Yes (same UUID after convert) |
| Profile card on Account | No | Yes |
| Avatar upload | No (403 on API) | Yes |
| Guest → full conversion | Yes | — |
| Delete account | No | Yes |
| Sign out | Yes | Yes |

Guest emails use `@arcori.arcori`. Full accounts use a personal email.

---

## Account screen (Flutter)

Single scroll view on `/account`:

1. **`AccountProfileCard`** — full accounts only: circular avatar (tap → gallery), username, email, **Regular** badge
2. **`GuestConvertBanner`** — guests only: CTA → Create tab
3. **TabBar** — Sign in | Create account
4. **`LoginForm` / `RegisterForm`**

**Form rules:**
- Sign in disabled when already signed in; sign out below
- Create account disabled when signed in as full account
- **Convert mode** (guest signed in): Create tab submits `convertGuestAccount`, stays on Account
- Convert form fields start empty (username not prefilled from guest)

Profile data comes from **`GET /authuser/user/profile`** (`userProfileProvider`), not only local secure storage.

---

## Bootstrap flow (Flutter)

```
refresh stored tokens → login with local profile → register new guest
```

- Orphaned guest (`invalid_credentials` on guest email): clear secure auth storage only, re-register guest once (bootstrap + manual sign-in)
- After sign-in / convert / register: stay on Account (no auto-nav home)

Local credentials: `flutter_secure_storage` via `LocalUserStorage`. SharedPreferences keyed by user id are untouched by auth flows.

---

## API endpoints

### Public auth (`/public/auth/*`)

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/public/auth/register` | Create user (`is_guest` optional) |
| POST | `/public/auth/login` | Email/password login |
| POST | `/public/auth/refresh` | New access token |
| POST | `/public/auth/dev-login` | Local debug only |

Register/login/refresh/convert responses: `{ user_id, access_token, refresh_token, token_type, is_guest }`.

### Authuser account (`/authuser/user/*`)

| Method | Path | Purpose | Guest allowed |
|--------|------|---------|---------------|
| GET | `/authuser/user/profile` | Profile JSON | Yes |
| POST | `/authuser/user/profile/avatar` | Multipart upload (`avatar` field) | **No** (403) |
| DELETE | `/authuser/user/profile/avatar` | Remove avatar | **No** (403) |
| POST | `/authuser/user/account/convert-guest` | In-place guest → full | Guest only |
| POST | `/authuser/user/account/delete` | Delete account (password + `DELETE`) | **No** (403) |

**Profile response fields:** `user_id`, `username`, `email`, `is_guest`, `account_type` (`Guest` | `Regular`), `avatar_url`, `created_at`.

---

## Guest → full account conversion

In-place **UPDATE** of the existing `users` row (same UUID) — preserves `login_events`, `example_module_records.user_id`, and client data keyed by user id.

```
POST /authuser/user/account/convert-guest
Authorization: Bearer <access_token>
Body: { "guest_email", "username", "email", "password" }
```

- `guest_email` must match the signed-in guest row (from local profile at submit time)
- New email must not be `@arcori.arcori`
- Returns fresh token pair with `is_guest: false`

---

## Profile avatar

**Full accounts only** (UI hidden for guests; API returns 403 for guest uploads).

| Setting | Value |
|---------|--------|
| Max upload | 2 MB |
| Accepted types | JPEG, PNG, WebP |
| Stored format | WebP, max 512×512 (aspect ratio preserved via `thumbnail`) |
| DB | `users.avatar_url` — e.g. `/media/avatars/{user_id}.webp` |
| Disk | Docker volume `arcori_uploads` → `/data/uploads/avatars/` |
| Serve | FastAPI `StaticFiles` at `/media/*` |

**Env** (`.env.local` / `.env.prod`):

```
UPLOAD_ROOT=/data/uploads
AVATAR_MAX_UPLOAD_BYTES=2097152
AVATAR_MAX_DIMENSION=512
AVATAR_WEBP_QUALITY=82
```

**Dependencies:** `python-multipart` required for multipart parsing; `Pillow` for image processing.

**Flutter:** `image_picker` (gallery), client-side 2 MB / type checks, `resolveMediaUrl()` prepends `ARCORI_API_REST_URL`.

---

## Delete account

Full accounts only. Centered modal: type `DELETE` + password.

```
POST /authuser/user/account/delete
Body: { "password", "confirmation": "DELETE" }
```

Clears local session + secure profile; removes avatar file from disk.

---

## Login events (audit)

Table `login_events` (migration `004_login_events`): `user_id`, `client_ip`, `user_agent`, `created_at`. Recorded on register, login, refresh path login, convert-guest.

---

## Database migrations

| Revision | Content |
|----------|---------|
| `003_users` | `users` table |
| `004_login_events` | Login audit table |
| `005_user_avatar_url` | `users.avatar_url` nullable |

---

## Implementation checklist

- [x] Users model, bcrypt, `user_repository`
- [x] Register / login / refresh / profile
- [x] Flutter bootstrap + guest auto-register
- [x] Account screen (sign in, create, convert, delete)
- [x] Guest → full conversion (same UUID)
- [x] Orphaned guest recovery
- [x] Login events
- [x] Profile card + avatar upload (full accounts only)
- [x] Avatar storage on Docker volume + WebP pipeline
- [x] Tests (auth, convert, avatar, profile provider)

---

## Key files

### Python (`python_base_05`)
- `bin/models/user.py`, `bin/models/login_event.py`
- `bin/modules/auth/` — auth_service, user_repository, auth_app
- `bin/modules/user/` — user_app, avatar_service, upload_config
- `bin/core/http/service/routes.py` — multipart + `/media` mount
- `alembic/versions/003_users.py`, `004_login_events.py`, `005_user_avatar_url.py`
- `tests/modules/auth/`, `tests/modules/user/`

### Flutter (`flutter_base_06`)
- `lib/core/state/auth/` — auth_providers, local storage, guest factory
- `lib/core/state/user/user_profile_provider.dart`
- `lib/core/http/` — auth_api_client, user_api_client, media_url
- `lib/modules/auth/` — account_screen, profile card, guest banner, forms
- `test/core/state/auth_notifier_test.dart`, `user_profile_provider_test.dart`

### Documentation
- `Documentation/03_Base/SECURITY_SYSTEM.md`
- `Documentation/02_FlowCharts/charts/base/security-auth-flow.guide.md`

---

## Notes

- Guest auto-register is always-on (all environments).
- `dev-login` is debug tooling only.
- Rebuild API image after `requirements.txt` changes (`python-multipart`, `Pillow`).
- Run `alembic upgrade head` after pulling migrations.

## Out of scope (deferred)

- Google Sign-In → JWT exchange
- Email verification / password strength beyond 6-char minimum
- Caddy direct static serve for `/media/*` (phase 2 perf)
- Server distinguishing wrong-password vs orphaned guest on login
- Login history UI on profile
