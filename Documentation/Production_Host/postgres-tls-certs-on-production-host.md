# PostgreSQL TLS — create certs on the production host

Operator guide for generating TLS material **on the production VPS** so traffic between application servers and PostgreSQL is encrypted in transit.

**Scope:** Production host only. Local debug compose (`docker-compose.debug.yml`) does **not** use these certs.

**Related:** Implementation plan — [postgres-tls-in-transit.md](../01_Active_Plans/postgres-tls-in-transit.md). Repo automation (planned) — `automation/production/postgres_tls/`.

---

## Why certs live on the production host

| Requirement | Reason |
|-------------|--------|
| Generate on VPS | Private CA and server private key must never be committed to git or built into images |
| Persist under app root | Docker Compose bind-mounts the same directory into Postgres and API containers |
| One CA per deployment | FastAPI, Adminer, `psql`, and backup scripts trust this CA to verify the DB server |

Today connections use plain `postgresql://…@Arcori_postgres:5432/…` on the Docker network. After TLS is enabled, Postgres listens with `ssl=on` and clients connect with `sslmode=verify-full` (or `verify-ca`) using the mounted CA file.

```text
Production VPS (host filesystem)
  /opt/apps/arcori/data/postgres/tls/
    ca.pem          ← trust anchor (mounted into API + operator tools)
    ca-key.pem      ← CA private key (host only — never in app containers)
    server.crt      ← Postgres server certificate
    server.key      ← Postgres server private key

Docker (app-network)
  Arcori_postgres  ← ssl=on, reads server.crt / server.key
  Arcori_api         ← DATABASE_URL + sslrootcert=ca.pem
  Operator psql/pg_dump  ← PGSSLROOTCERT pointing at host copy of ca.pem
```

Dart does not talk to Postgres directly; only **FastAPI** and **operator/automation** tools need TLS client configuration.

---

## Paths and naming

| Item | Default |
|------|---------|
| App root on VPS | `/opt/apps/arcori` |
| TLS directory (host) | `/opt/apps/arcori/data/postgres/tls` |
| In-container mount | `/etc/postgres-tls/` (read-only) |
| Postgres service name | `Arcori_postgres` (Docker DNS — must appear in cert SANs) |
| CA common name | `wf-template-pg-ca` |

Set `APP_ROOT` in `.env.prod` if your deploy path differs.

---

## Prerequisites

- SSH access to the production VPS (preferably via WireGuard — see [vps-wireguard-vpn-automation.md](../01_Active_Plans/vps-wireguard-vpn-automation.md)).
- `openssl` on the host.
- Root or `sudo` for creating directories and fixing permissions.
- Stack already deployed at `APP_ROOT` with `docker/docker-compose.yml`.

---

## Step 1 — Create the TLS directory on the host

On the **production VPS**:

```bash
export APP_ROOT=/opt/apps/arcori
export TLS_DIR="${APP_ROOT}/data/postgres/tls"

sudo mkdir -p "${TLS_DIR}"
sudo chmod 700 "${TLS_DIR}"
```

---

## Step 2 — Generate private CA + Postgres server cert

Run on the **production VPS as root** (not on your laptop — the private keys stay on the host).

```bash
export TLS_DIR=/opt/apps/arcori/data/postgres/tls
export DAYS_CA=3650
export DAYS_SERVER=825
export TLS_CA_CN=wf-template-pg-ca

WORK=$(mktemp -d)
trap 'rm -rf "${WORK}"' EXIT

# Private CA
openssl genrsa -out "${WORK}/ca-key.pem" 4096
openssl req -x509 -new -nodes -key "${WORK}/ca-key.pem" -sha256 -days "${DAYS_CA}" \
  -out "${WORK}/ca.pem" -subj "/CN=${TLS_CA_CN}"

# Server key + CSR
openssl genrsa -out "${WORK}/server.key" 2048
openssl req -new -key "${WORK}/server.key" -out "${WORK}/server.csr" \
  -subj "/CN=Arcori_postgres"

# SANs: Docker service name, localhost, loopback (required for verify-full from API container)
cat > "${WORK}/server.ext" <<EOF
subjectAltName = DNS:Arcori_postgres,DNS:localhost,IP:127.0.0.1
extendedKeyUsage = serverAuth
EOF

openssl x509 -req -in "${WORK}/server.csr" \
  -CA "${WORK}/ca.pem" -CAkey "${WORK}/ca-key.pem" -CAcreateserial \
  -out "${WORK}/server.crt" -days "${DAYS_SERVER}" -sha256 \
  -extfile "${WORK}/server.ext"

# Install under TLS_DIR
sudo install -m 644 "${WORK}/ca.pem" "${TLS_DIR}/ca.pem"
sudo install -m 600 "${WORK}/ca-key.pem" "${TLS_DIR}/ca-key.pem"
sudo install -m 644 "${WORK}/server.crt" "${TLS_DIR}/server.crt"
sudo install -m 600 "${WORK}/server.key" "${TLS_DIR}/server.key"
sudo chmod 755 "${TLS_DIR}"

ls -la "${TLS_DIR}"
```

Expected files:

| File | Mode | Used by |
|------|------|---------|
| `ca.pem` | 644 | API container, `psql`, `pg_dump`, Adminer |
| `ca-key.pem` | 600 | CA rotation only — **not** mounted into containers |
| `server.crt` | 644 | Postgres container |
| `server.key` | 600 | Postgres container |

---

## Step 3 — Fix permissions for the Postgres container user

The official `postgres:16` image runs as UID **999**. The server key must be readable by that user inside the container (via bind mount).

On the host:

```bash
TLS_DIR=/opt/apps/arcori/data/postgres/tls

sudo chmod 755 "${TLS_DIR}"
sudo chmod 644 "${TLS_DIR}/ca.pem" "${TLS_DIR}/server.crt"
sudo chmod 600 "${TLS_DIR}/server.key" "${TLS_DIR}/ca-key.pem"
```

If Postgres fails to start with “permission denied” on the key, confirm `server.key` is `600` and the mount is read-only. Do **not** loosen `ca-key.pem` beyond root-only.

---

## Step 4 — Wire Docker Compose (after repo TLS support lands)

Once [postgres-tls-in-transit.md](../01_Active_Plans/postgres-tls-in-transit.md) is implemented, production compose will:

1. Mount `${APP_ROOT}/data/postgres/tls` → `/etc/postgres-tls:ro` on `Arcori_postgres` and `Arcori_api`.
2. Start Postgres with SSL enabled, for example:

   ```text
   -c ssl=on
   -c ssl_cert_file=/etc/postgres-tls/server.crt
   -c ssl_key_file=/etc/postgres-tls/server.key
   ```

3. Set API `DATABASE_URL` with TLS query params, for example:

   ```text
   postgresql://USER:PASS@Arcori_postgres:5432/DB?sslmode=verify-full&sslrootcert=/etc/postgres-tls/ca.pem
   ```

4. Set in `.env.prod`:

   ```bash
   APP_ROOT=/opt/apps/arcori
   PG_TLS_ENABLED=1
   PG_SSLMODE=verify-full
   PG_SSLROOTCERT=/etc/postgres-tls/ca.pem
   ```

Redeploy from the host:

```bash
cd /opt/apps/arcori/docker
docker compose --env-file ../.env.prod -f docker-compose.yml up -d
```

**Order of operations:** create certs on the host **first**, then deploy compose changes that mount them and enable SSL on clients.

---

## Step 5 — Verify TLS in transit

### API health (through Caddy or localhost)

```bash
curl -sS https://<CADDY_DOMAIN>/health | jq .
# Expect: "db": "ok"
```

### From inside the API container

```bash
docker exec Arcori_api python -c "
import os, psycopg
url = os.environ['DATABASE_URL']
with psycopg.connect(url, connect_timeout=5) as c:
    print(c.execute('SELECT 1').fetchone())
"
```

### From the host (VPN / published port `127.0.0.1:5433`)

Copy or reference the CA on the host, then:

```bash
export PGSSLMODE=verify-full
export PGSSLROOTCERT=/opt/apps/arcori/data/postgres/tls/ca.pem

psql "postgresql://${POSTGRES_USER}@127.0.0.1:5433/${POSTGRES_DB}?sslmode=verify-full" -c 'SELECT 1'
```

Plain (non-SSL) connections should fail once Postgres is configured to require SSL on TCP (`hostssl` in `pg_hba.conf` — optional hardening phase).

### Confirm SSL is active on the server

```bash
docker exec Arcori_postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "SHOW ssl;"
# Expect: on
```

---

## Automation (planned)

Manual steps above will be wrapped by scripts in the repo:

| Script | Role |
|--------|------|
| `automation/production/postgres_tls/generate_certs.sh` | Same OpenSSL flow as Step 2 |
| `automation/production/postgres_tls/fix_tls_permissions.sh` | Step 3 |
| `automation/production/postgres_tls/install_pg_tls_certs.sh` | Upload scripts via SSH and run on VPS |

Until those exist, use the manual commands in this document on the production host.

The copied Dutch Mongo scripts under `automation/production/mongodb_tls/` are **not** for this stack — do not use them for PostgreSQL.

---

## Cert rotation

1. Stop or drain traffic if required (see [drain-maintenance-pipeline.md](../01_Active_Plans/drain-maintenance-pipeline.md)).
2. Re-run Step 2 with a backup of the old directory (or `generate_certs.sh --force` when automation exists).
3. Redeploy Postgres + API containers.
4. Update any off-host backup tooling with the new `ca.pem`.
5. Revoke trust in the old CA after all clients are updated.

Rotating the CA is disruptive — prefer reissuing only `server.crt` / `server.key` while keeping the same CA when possible.

---

## Security notes

- Never commit `ca-key.pem`, `server.key`, or `.env.prod` to git.
- Do not bake TLS private keys into Docker images.
- Keep `:5432` / host port `5433` reachable only via VPN or `127.0.0.1` bind — TLS adds encryption; firewall limits exposure.
- Store a secure offline backup of `ca-key.pem` if you need to reissue server certs after host loss.

---

## Checklist

- [ ] TLS directory created on production host under `${APP_ROOT}/data/postgres/tls`
- [ ] `ca.pem`, `ca-key.pem`, `server.crt`, `server.key` generated **on the VPS**
- [ ] Permissions set (Step 3)
- [ ] Compose mounts + Postgres `ssl=on` deployed (after repo implementation)
- [ ] `.env.prod` has `PG_TLS_ENABLED=1` and SSL client settings
- [ ] `/health` reports `db: ok`
- [ ] `psql` from host over VPN succeeds with `PGSSLMODE=verify-full`
