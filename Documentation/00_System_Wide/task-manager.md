# Task Manager — board API, data model, dashboard link

Per-repo planning board used alongside `Documentation/01_Active_Plans/`. The wfrun dashboard **Task Manager** tab embeds this repo’s label; agents sync plan progress to the same label via the JSON API.

Canonical product/code lives under `/Users/sil/Documents/Work/00Utilities/task_manager` (PHP + MariaDB). This template only consumes it (env + dashboard iframe + agent curls).

---

## This repo’s label (dashboard)

| Env key | Role |
|---------|------|
| `TASK_MANAGER_BASE_URL` | HTTP origin only (no trailing slash), e.g. `http://tm.reignofplay.com`. **No TLS** on this host — do not use `https://`. |
| `TASK_MANAGER_SLUG` | **URL slug** for this product’s label (must match DB `board_label.slug`) |
| `TM_USERNAME` | Task Manager API / UI login username |
| `TM_PASSWORD` | Task Manager API / UI login password |
| `TM_JWT_SECRET` | Align with Task Manager server `JWT_SECRET` (ops; not sent on client API calls) |

Legacy (if `TASK_MANAGER_BASE_URL` unset): `TASK_MANAGER_HOST` + optional `TASK_MANAGER_PORT`.

Defined in [`.env.local.sample`](../../.env.local.sample) / [`.env.prod.sample`](../../.env.prod.sample) (copy into `.env.local` / `.env.prod`). **Do not hardcode origin/secrets in code.** Never commit real passwords or JWT secrets.

**Slug rule:** `label-create` stores `board_slugify(text)` — lowercase, non-alphanumeric runs → `-`. Examples: `wf_template` → `wf-template`, `my_cool_app` → `my-cool-app`, `arcori` → `arcori`. Set `TASK_MANAGER_SLUG` to that hyphenated slug (not necessarily the raw snake brand). After create, prefer the `slug` field from the API response.

| Surface | URL |
|---------|-----|
| **Dashboard tab** (iframe, `embed=1`) | `$TASK_MANAGER_BASE_URL/content/label.php?slug=$TASK_MANAGER_SLUG&embed=1` |
| **API base** | `$TASK_MANAGER_BASE_URL` |
| **Read board** | `GET /api/label-get.php?slug=$TASK_MANAGER_SLUG` |

`wfstart` creates the label after branding (`POST /api/label-create.php` with `{"text":"<snake_brand>"}`).

Open the board in the browser via **wfrun → dashboard → Task Manager**.

**Embed / framing:** The dashboard iframe loads Task Manager through a **same-origin proxy** at `/tm/...` (not the remote origin directly). Cross-site iframes cannot keep the PHP session cookie, which broke login with “Invalid form token” (CSRF). The proxy rewrites cookies/`Location`/root-absolute URLs so session + CSRF work on `http://127.0.0.1:8765/tm/...`.

Remote origin remains `TASK_MANAGER_BASE_URL` (`http://tm.reignofplay.com`, **no TLS**). Nginx may still send `X-Frame-Options: SAMEORIGIN` on the origin; the proxy strips that for the iframe.

---

## Hierarchy

```
board_label (slug = TASK_MANAGER_SLUG)
  ├── board_category (optional grouping per label: Backend, Frontend, …)
  └── board_task (title = work package / plan section)
        ├── category_id → board_category | null   (at most one category per task)
        └── board_task_item
              ├── kind=checklist  (done checkbox)
              └── kind=note       (free text; no checkbox)
```

Mirror active-plan markdown roughly as:

- **Plan / major workstream** → one **task**
- **Area / layer** (optional) → **category** on that task (reuse existing category names from `label-get`)
- **Implementation steps** → **checklist** items on that task
- **Decisions / blockers / context** → **note** items on that task

Unassigned tasks have `category_id: null` and `category: null`.

---

## Database (MariaDB)

Schema: `web_codebase/mariadb/init/02-board-schema.sql` (also ensured at runtime by `includes/board-migrate.php`).

| Table | Purpose |
|-------|---------|
| `board_label` | Board column/label: `id`, unique `slug`, `name`, `description`, `sort_order` |
| `board_category` | Categories **per label**: `id`, `label_id` → label, `name`, `sort_order` |
| `board_task` | Card under a label: `id`, `label_id` → label, optional `category_id` → category, `title`, `sort_order` |
| `board_task_item` | Line on a card: `id`, `task_id` → task, `kind` ENUM(`checklist`,`note`), `body`, `is_done`, `sort_order` |

Cascades / nulling:

- Deleting a **label** deletes its categories and tasks
- Deleting a **task** deletes its items
- Deleting a **category** sets `board_task.category_id` to **NULL** (`ON DELETE SET NULL`)

### Local containers (Task Manager repo)

From the task_manager `web_dev` tree, debug Compose runs **MariaDB only** on host port **3309**:

- Compose: `docker/docker-compose.debug.yml` (`name: task_manager_debug`)
- Container: `task_manager_db_debug`
- Init SQL: `web_codebase/mariadb/init/` mounted into `/docker-entrypoint-initdb.d`
- Volume: `task_manager_debug_db_data`
- Env: repo `.env.local` (`MYSQL_*` / app DB settings)

PHP for local debug typically runs on the host (not in that debug compose file). Production is served at `TASK_MANAGER_BASE_URL` (e.g. `http://tm.reignofplay.com`).

Agents usually talk to the **HTTP JSON API** on `$TASK_MANAGER_BASE_URL`, not the DB directly.

---

## JSON board API

- Base: `$TASK_MANAGER_BASE_URL`
- All under `/api/`
- **Auth required:** `Authorization: Bearer <jwt>` on board endpoints (see [Auth](#auth-jwt))
- JSON body on POST; success `{ "ok": true, ... }`; error `{ "ok": false, "error": "..." }`
- Helpers: `includes/api-json.php` (`api_require_auth`)

### Auth (JWT)

```bash
POST /api/login.php
Body: { "username": "...", "password": "..." }
# 200: { "ok": true, "token": "<jwt>", "expires_in": 86400, "username": "..." }
```

Agents load `TM_USERNAME` / `TM_PASSWORD` from `.env.local`, call login, then pass `Authorization: Bearer $token` on label/task/item calls. On `401`, re-login once. Do not log passwords or tokens.

Optional server `BOARD_API_KEY` (Bearer or `X-Api-Key`) is an alternate auth path for automation services — product agents should use username/password → JWT.

**Deploy note:** The VPS tree must include the full `web_codebase/api/*.php` set (including `login.php`). If board routes return Apache HTML 404, redeploy Task Manager from `/Users/sil/Documents/Work/00Utilities/task_manager`.

### Read

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/label-get.php?label_id=1` | One label + categories + tasks + items |
| GET | `/api/label-get.php?slug=planning` | Same by slug |

Example success shape:

```json
{
  "ok": true,
  "categories": [{ "id": 2, "name": "Backend" }],
  "label": {
    "id": 1,
    "slug": "wf-template",
    "name": "wf_template",
    "description": "",
    "categories": [{ "id": 2, "name": "Backend" }],
    "tasks": [
      {
        "id": 10,
        "label_id": 1,
        "title": "Dashboard main tabs",
        "category_id": 2,
        "category": { "id": 2, "name": "Backend" },
        "items": [
          { "id": 100, "kind": "checklist", "text": "Add Scripts tab", "done": true },
          { "id": 101, "kind": "note", "text": "embed=1 hides site chrome", "done": false }
        ]
      }
    ]
  }
}
```

Top-level `categories` and `label.categories` list categories available on that label. Unassigned tasks: `"category_id": null`, `"category": null`.

### Labels

| Method | Path | Body |
|--------|------|------|
| POST | `/api/label-create.php` | `{ "text": "..." }` (alias `name`) → `{ ok, id, name, slug }` |

### Categories

Categories are scoped to a label (`board_category.label_id`). Create / delete / filter are available in the **label UI**; assign on task create/update via the task JSON API below.

Invalid or foreign `category_id` values are normalized to `null` (`board_normalize_category_for_label`). Deleting a category clears `category_id` on its tasks (does not delete the tasks).

**Agents:** reuse category `id` / `name` from `label-get`. Do **not** delete categories without explicit user permission (same rule as other deletes).

### Tasks

| Method | Path | Body |
|--------|------|------|
| POST | `/api/task-create.php` | `{ "label_id", "title", category? }` — see category shapes below |
| POST | `/api/task-update.php` | `{ "task_id", "title", "label_id"?, "category_id"? }` — omit `category_id` to keep; `null`/`""` clears |
| POST | `/api/task-delete.php` | `{ "task_id", "label_id"? }` |

`title` alias on create: `text`. Response includes `category_id` and `category: { id, name } | null`.

**Category on `task-create`** — first valid shape wins; only one category is stored:

| Field | Example |
|-------|---------|
| `category_id` | `{ "category_id": 2 }` |
| `category` | `2`, `"Backend"`, or `{ "id": 2 }` |
| `categories` | `[2]` or `[{ "id": 2 }]` (first entry used) |
| `category_name` | `"Backend"` (looked up on that label) |

### Items (checklist + notes)

| Method | Path | Body |
|--------|------|------|
| POST | `/api/item-add.php` | `{ "task_id", "text", "kind": "checklist"\|"note", "label_id"? }` |
| POST | `/api/item-add-checklist.php` | `{ "task_id", "text", "label_id"? }` |
| POST | `/api/item-add-note.php` | `{ "task_id", "text", "label_id"? }` |
| POST | `/api/item-update.php` | `{ "item_id", "text"?, "is_done"? }` |
| POST | `/api/item-check.php` | `{ "item_id", "is_done": true\|false }` — checklist only |
| POST | `/api/item-delete.php` | `{ "item_id" }` |

Optional `label_id` on task/item writes must match ownership when provided.

---

## Agent curl examples

Resolve host/port/slug from the project `.env.local` (or current `wfrun` env), then:

```bash
BASE="${TASK_MANAGER_BASE_URL}"
SLUG="${TASK_MANAGER_SLUG}"

# Login (creds from .env.local — never echo password/token)
TOKEN=$(curl -sS -X POST "${BASE}/api/login.php" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${TM_USERNAME}\",\"password\":\"${TM_PASSWORD}\"}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
AUTH="Authorization: Bearer ${TOKEN}"

# Load current board for this repo (includes categories)
curl -sS "${BASE}/api/label-get.php?slug=${SLUG}" -H "$AUTH"

# Ensure label exists (wfstart usually already did this)
curl -sS -X POST "${BASE}/api/label-create.php" \
  -H "Content-Type: application/json" -H "$AUTH" \
  -d "{\"text\":\"${SLUG}\"}"

# Create a task with category (id from label-get.categories)
curl -sS -X POST "${BASE}/api/task-create.php" \
  -H "Content-Type: application/json" -H "$AUTH" \
  -d '{"label_id":1,"title":"Dashboard main tabs","category_id":2}'

# Or by category name on that label
curl -sS -X POST "${BASE}/api/task-create.php" \
  -H "Content-Type: application/json" -H "$AUTH" \
  -d '{"label_id":1,"title":"Dashboard main tabs","category_name":"Backend"}'

# Checklist step
curl -sS -X POST "${BASE}/api/item-add-checklist.php" \
  -H "Content-Type: application/json" -H "$AUTH" \
  -d '{"task_id":10,"text":"Wire Task Manager iframe"}'

# Note / decision
curl -sS -X POST "${BASE}/api/item-add-note.php" \
  -H "Content-Type: application/json" -H "$AUTH" \
  -d '{"task_id":10,"text":"Host/port live in .env only"}'

# Mark checklist done
curl -sS -X POST "${BASE}/api/item-check.php" \
  -H "Content-Type: application/json" -H "$AUTH" \
  -d '{"item_id":100,"is_done":true}'

# Clear or set category on update
curl -sS -X POST "${BASE}/api/task-update.php" \
  -H "Content-Type: application/json" -H "$AUTH" \
  -d '{"task_id":10,"title":"Dashboard main tabs","category_id":2}'
```

Prefer **GET label-get** first; reuse existing task/item/category ids. Avoid duplicate titles for the same open workstream—update/check instead of creating parallel cards.

**Deletes:** never call `task-delete` / `item-delete`, delete categories, or otherwise remove board data without explicit user permission for the specific item(s). See the active-plan rule’s “Deletes — always ask first.”

---

## Related

- Active-plan agent rule: [`.cursor/rules/create-update-active-plan.mdc`](../../.cursor/rules/create-update-active-plan.mdc)
- Dashboard GUI: [`wfrun-dashboard-gui.md`](wfrun-dashboard-gui.md) · [`wfrun.md`](wfrun.md)
- Label create on project start: [`wfstart.md`](wfstart.md)
