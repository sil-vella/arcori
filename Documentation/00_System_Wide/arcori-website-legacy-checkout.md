# Arcori website — Legacy preserve checkout contract

**Audience:** arcori **website** repo (storefront / checkout). Not implemented in the app monorepo.

**Purpose:** Charge and ship the **physical mint** only. Digital Legacy (Trove row, titles, Museum, echo generation) is fulfilled exclusively by the **app FastAPI** `service` endpoint. The website never mints digital Legacy itself.

One checkout may cover **multiple designs** when several Arcori reach preservation in the same match (batch intent).

---

## End-to-end (website role)

1. App opens system browser to checkout URL (below).
2. Website charges the physical mint(s) (Stripe or equivalent) for every design on the intent.
3. After payment success, website **server-side** calls app fulfill once (mints all designs on the intent).
4. Only after fulfill returns ok, redirect into the app deep link with `intentId` + `orderId`.

```text
App → website checkout → payment → POST app /service/legacy/fulfill → deep link return
```

---

## Checkout page

Suggested path: `/legacy/checkout`

### Required query params (from app)

| Param | Meaning |
|-------|---------|
| `intentId` | App-issued pending preserve checkout intent |
| `userId` | Paying player (must match intent) |
| `designId` | First design (compat / display) |
| `generationNumber` | First generation number (int ≥ 1) |
| `designIds` | Comma-separated design ids (all items on this checkout) |
| `generationNumbers` | Comma-separated gens aligned with `designIds` |
| `returnUrl` | Deep link base, typically `arcori://legacy-preserve-complete` |

Example (single):

```text
https://<arcori-site>/legacy/checkout
  ?intentId=…
  &userId=…
  &designId=foundations.kin
  &generationNumber=1
  &designIds=foundations.kin
  &generationNumbers=1
  &returnUrl=arcori://legacy-preserve-complete
```

Example (batch — three designs, one payment):

```text
https://<arcori-site>/legacy/checkout
  ?intentId=…
  &userId=…
  &designId=foundations.kin
  &generationNumber=1
  &designIds=foundations.kin,foundations.hearth,foundations.craft
  &generationNumbers=1,1,1
  &returnUrl=arcori://legacy-preserve-complete
```

Display order metadata for every id in `designIds`. Do **not** trust client-only mutation after load — bind them to the server order record at create time. Prefer charging one line item per design (or one SKU × quantity) that matches `designIds.length`.

---

## After payment success (order of operations)

**Must be server-side** (route handler / webhook worker). Never call fulfill from browser JS with service credentials.

1. **Persist local order** with a unique `orderId` (your store’s order id) covering all designs.
2. **`POST {APP_API}/service/legacy/fulfill`** with service auth and JSON body:

```json
{
  "orderId": "<unique store order id>",
  "intentId": "<from checkout query>",
  "userId": "<from checkout query>",
  "designIds": "foundations.kin,foundations.hearth,foundations.craft",
  "generationNumbers": "1,1,1"
}
```

Single-design body still accepted:

```json
{
  "orderId": "<unique store order id>",
  "intentId": "<from checkout query>",
  "userId": "<from checkout query>",
  "designId": "foundations.kin",
  "generationNumber": 1
}
```

Fulfill mints **every design stored on the intent** (app is source of truth). Query/body design lists are validated against the intent when provided.

3. Treat **`already_applied` / replay** as success (same `orderId` may be retried safely).
4. **Redirect** to `returnUrl` with query params:

```text
{returnUrl}?intentId=…&orderId=…
```

Prefer redirect **only after** fulfill returns `{ "ok": true, … }`. Do not deep-link a “success” UX if fulfill failed.

---

## Auth

- Use the app’s **`service`** tier credentials (same pattern as other server→server routes).
- Env on the website server only (e.g. `ARCORI_APP_API_BASE`, `ARCORI_SERVICE_TOKEN`).
- **Never** expose the service token in frontend JS, static HTML, or client bundles.

---

## Idempotency

- App ledger is unique on `orderId`. Calling fulfill twice with the same `orderId` returns a cached ok-style payload (`reason: already_applied`).
- Website may retry fulfill on network errors after payment; safe as long as `orderId` is stable.
- Do **not** invent a new `orderId` on retry for the same paid checkout.

---

## Failure UX

| Situation | Website behavior |
|-----------|------------------|
| Payment fails | Stay on checkout; no fulfill; no deep link |
| Payment ok, fulfill fails | Retry fulfill; show “processing / contact support” with `orderId`; **do not** deep-link success until fulfill ok |
| Fulfill ok, deep link fails | User can reopen app; digital mint is already applied; support can confirm via `orderId` |

---

## Local / dev stub

No Stripe required for app integration testing:

1. Stub checkout page with a **“Mark paid (dev)”** button.
2. Server generates a fake unique `orderId` (e.g. `dev-<uuid>`).
3. Calls fulfill with the query params + fake `orderId`.
4. Redirects to `returnUrl?intentId=…&orderId=…`.

Batch stub: pass through `designIds` / `generationNumbers` unchanged so fulfill can validate against the intent.
