# VPS + WireGuard VPN — secure automation access

**Status**: In Progress — **pipeline design requires refinement** (see [Pipeline refinement](#pipeline-refinement-required))  
**Created**: 2026-07-10  
**Last Updated**: 2026-07-10

## Objective

Provision a new production VPS, run the WF template stack (Docker Compose + Caddy), and put all operator automation behind a **WireGuard VPN**. Scripts that today run from a developer machine against the VPS (via `wfrun`, `expenvs.sh`, or direct SSH/API) must **exit through the VPN**; the VPS must **reject** SSH, database, Adminer, and other admin paths unless the source IP is on the VPN tunnel.

Public traffic (HTTPS `:443` to Caddy → FastAPI / Dart) stays reachable for end users. Only **management and automation** surfaces are VPN-gated.

## Context (current state)

| Area | Today |
|------|--------|
| Backend automation | `automation/backend/` — `docker_up_build.sh`, `sync_global_notifications.py`, `build_nav_and_charts.py`, … |
| Frontend automation | `automation/frontend/` — Flutter launch/build scripts |
| Runner | `wfrun` (`~/bin`) loads `.env.local` / `.env.prod` and executes `automation/**` |
| Legacy runner | `expenvs.sh` — same idea, no dart-defines profile |
| Prod stack | `docker/docker-compose.yml` + `.env.prod` on VPS — see [PRODUCTION_SYSTEM.md](../03_Base/PRODUCTION_SYSTEM.md) |
| Secrets | `.env.prod`, `.env.dart.defines.prod` — see [wfsecrets.md](../00_System_Wide/wfsecrets.md) |

Prod-mode scripts (`wfrun` → `prod`) already target VPS hostnames/URLs from `.env.prod`. Today those connections typically use the machine's **public** egress IP with no VPN requirement.

## Target architecture

```text
Developer machine                    WireGuard              VPS (new)
┌─────────────────────┐         ┌──────────────┐      ┌─────────────────────────┐
│ wfrun / automation  │──WG────▶│ 10.8.0.0/24  │─────▶│ wg0 (10.8.0.1)          │
│ (prod profile)      │  tunnel │              │      │                         │
└─────────────────────┘         └──────────────┘      │ UFW / nftables:         │
                                                      │  allow SSH, :5432,      │
                                                      │  :8081, internal API    │
                                                      │  ONLY from 10.8.0.0/24  │
                                                      │                         │
Internet users ──────────────────────────────────────▶│ Caddy :443 (public)     │
                                                      └─────────────────────────┘
```

## Implementation steps

### Phase 1 — VPS baseline

- [ ] Choose provider, region, and instance size (match [PRODUCTION_SYSTEM.md](../03_Base/PRODUCTION_SYSTEM.md) tuning: workers, Postgres disk).
- [ ] Create VPS with SSH key auth; disable password login.
- [ ] Harden OS: unattended upgrades, non-root deploy user, `fail2ban` (optional).
- [ ] Install Docker + Docker Compose plugin.
- [ ] Clone/deploy repo; copy `.env.prod` from sample — **never commit secrets**.
- [ ] Bring up stack: `docker compose --env-file ../.env.prod -f docker-compose.yml up -d --build`.
- [ ] Verify public health: `curl https://<api-domain>/health`.

### Phase 2 — WireGuard on VPS

- [ ] Install WireGuard (`apt install wireguard` or distro equivalent).
- [ ] Generate server keys; configure `wg0` (e.g. `10.8.0.1/24`, listen `UDP 51820`).
- [ ] Add peer config(s) for each developer/automation machine (client `10.8.0.x/32`).
- [ ] Enable IP forwarding if clients route all automation traffic through VPN (`net.ipv4.ip_forward=1`).
- [ ] Persist config (`wg-quick@wg0` systemd unit).
- [ ] Document server public key, endpoint, and client IP assignments in **private** ops store (not git).

### Phase 3 — WireGuard clients (dev machines)

- [ ] Install WireGuard on each machine that runs prod automation.
- [ ] Import client config; set `AllowedIPs` so VPS management addresses route via tunnel (minimal split-tunnel: VPS public IP or `10.8.0.0/24` only).
- [ ] Verify: with VPN up, `ssh deploy@<vps>` works; with VPN down, SSH **times out / refused**.
- [ ] Optional: `wg-quick@wg0` autostart on login for operators who run `wfrun` daily.

### Phase 4 — VPS firewall (IP must match VPN)

- [ ] Default deny on management ports; allow only from WireGuard subnet (`10.8.0.0/24`) and optionally `lo`:
  - SSH (`22/tcp`)
  - Postgres (`5432/tcp`) — if remote sync/migrations ever hit host port
  - Adminer (`8081/tcp`) — debug-only; prefer omitting from prod compose
  - Any future Ansible/SSH tunnel ports
- [ ] Keep **public** allow: `80/tcp`, `443/tcp` (Caddy), `51820/udp` (WireGuard).
- [ ] Confirm Docker-published ports respect host firewall (bind admin ports to `127.0.0.1` or VPN interface where possible).
- [ ] Test matrix:

| Action | VPN off | VPN on |
|--------|---------|--------|
| `curl https://<domain>/health` | ✅ | ✅ |
| `ssh deploy@vps` | ❌ | ✅ |
| `wfrun` → `sync_global_notifications.py` (prod) | ❌ | ✅ |
| Direct Postgres to host `:5432` | ❌ | ✅ |

### Phase 5 — Automation through VPN

- [ ] Inventory prod-touching scripts (initial list):
  - `automation/backend/docker_up_build.sh` (prod compose rebuild)
  - `automation/backend/sync_global_notifications.py`
  - Future Ansible playbooks (`*.yml` via `wfrun`)
  - Manual `ssh` / `scp` / DB tools using `.env.prod` hostnames
- [ ] Add VPN guard helper (e.g. `automation/backend/require_vpn.sh`):
  - When `WFRUN_MODE=prod`, verify WireGuard interface is up (`wg show wg0`) **or** egress to VPS matches expected VPN client IP / `10.8.0.x`.
  - Fail fast with clear message if not connected.
- [ ] Source guard from prod paths in `docker_up_build.sh`, `sync_global_notifications.py`, and any new remote scripts.
- [ ] Update [wfrun.md](../00_System_Wide/wfsecrets.md) with “prod requires VPN” policy.
- [ ] Consider `wfrun` wrapper enhancement (in `~/bin/wfrun`): optional pre-flight VPN check before loading `.env.prod`.

### Phase 6 — Documentation and ops

- [ ] Add `Documentation/03_Base/VPN_OPS.md` (or section in PRODUCTION_SYSTEM) — client setup, key rotation, firewall rules.
- [ ] Record VPN client IP ↔ peer mapping in private ops doc.
- [ ] Key rotation procedure: new peer keys, revoke old, update firewall if subnet changes.
- [ ] Onboarding checklist for new developers (WireGuard config + `wfrun` prod smoke test).

### Phase 7 — Pipeline refinement (required)

The current automation path (`wfrun` / `expenvs.sh` → local script → direct VPS access) is a **first draft**. Before treating VPN gating as complete, refine the end-to-end pipeline for better practices:

- [ ] **Review and document** the full prod pipeline: who runs what, from where, with which secrets, and on what trigger (manual, scheduled, CI).
- [ ] **Separate concerns:** distinguish deploy (immutable images + compose pull), data sync (e.g. notifications seed), migrations, and day-2 ops — avoid one-off SSH + ad hoc scripts where a repeatable playbook or CI job fits.
- [ ] **Idempotent, auditable steps:** prefer versioned deploy artifacts, explicit health gates post-deploy, and logged runs (what changed, who ran it).
- [ ] **Secrets handling:** no long-lived prod creds on laptops where avoidable; evaluate short-lived tokens, deploy keys scoped to VPN peers, and secret store vs flat `.env.prod` on operator machines.
- [ ] **CI vs human operators:** define whether prod touches go through GitHub Actions (WireGuard peer for runner), a dedicated bastion, or VPN-only laptops — and document the single blessed path.
- [ ] **Rollback and blast radius:** document how to revert a bad deploy/sync without bypassing VPN or firewall rules.
- [ ] **Align runners:** consolidate on `wfrun` (retire or clearly demote `expenvs.sh`); single preflight layer (VPN + env + optional `prod` confirmation).
- [ ] **Capture decisions** in `VPN_OPS.md` / `PRODUCTION_SYSTEM.md` once the refined pipeline is agreed — update Phases 5–6 implementation to match, not the other way around.

> **Gate:** Do not mark this plan **Completed** until Phase 7 outcomes are written down and at least one prod workflow (e.g. deploy or notification sync) follows the refined pipeline end-to-end.

## Pipeline refinement (required)

This plan intentionally leaves the **deployment and automation pipeline** underspecified. VPN IP allowlisting solves network exposure; it does not by itself make deploys safe or repeatable.

| Gap (today) | Refinement target |
|-------------|-------------------|
| Interactive `wfrun` menu, prod scripts run from developer machines | Explicit prod workflow: manual runbook vs CI job, with ownership |
| Mixed local/prod env loading in one runner | Clear boundary: local compose vs remote deploy/sync commands |
| Direct host SSH + compose rebuild | Image build/push, tagged releases, pull-only on VPS where possible |
| Script-level VPN guard only | Defense in depth: VPN + firewall + app auth + pipeline gates (health check, dry-run) |
| Legacy `expenvs.sh` parallel to `wfrun` | One supported operator entry point |

Phase 7 is **blocking for “done”** — infrastructure (Phases 1–4) and script guards (Phase 5) can proceed in parallel with pipeline design, but implementation should be adjusted once better practices are chosen.

## Current progress

Planning only. No VPS provisioned; no WireGuard or firewall rules applied in this repo yet.

## Next steps

1. **Refine prod pipeline** (Phase 7): agree deploy vs sync vs ops workflows, CI vs VPN-only operators, and document before locking script behavior.
2. Provision VPS and deploy Docker Compose prod stack.
3. Install and test WireGuard server + one client peer.
4. Apply host firewall rules; validate allow/deny matrix.
5. Implement `require_vpn` guard and wire into prod automation scripts **per refined pipeline**.
6. Document client setup and update `wfrun.md` / `wfsecrets.md`.

## Files to create or modify (expected)

| File | Change |
|------|--------|
| `automation/backend/require_vpn.sh` | New — VPN connectivity preflight for prod |
| `automation/backend/docker_up_build.sh` | Call VPN guard when `WFRUN_MODE=prod` |
| `automation/backend/sync_global_notifications.py` | Call VPN guard when `WFRUN_MODE=prod` |
| `Documentation/00_System_Wide/wfrun.md` | Prod + VPN requirement |
| `Documentation/00_System_Wide/wfsecrets.md` | VPS access policy |
| `Documentation/03_Base/PRODUCTION_SYSTEM.md` | Link VPN ops / firewall section |
| `Documentation/03_Base/VPN_OPS.md` | New — WireGuard server/client runbook |
| VPS host (out of repo) | `/etc/wireguard/wg0.conf`, UFW/nftables, Docker compose deploy |

## Notes

- **Split tunnel vs full tunnel:** Prefer split tunnel (`AllowedIPs` = VPS public IP or `10.8.0.0/24`) so general browsing does not route through VPS.
- **SSH over VPN:** Point `.env.prod` / SSH config at VPS **public** IP; firewall allows SSH only from VPN subnet, so connection still requires tunnel even if target is public IP (packets arrive from `10.8.0.x` after WG routing). Alternatively use `10.8.0.1` as SSH host when on VPN.
- **Service key / JWT:** VPN protects **network path**; app-layer auth (`SERVICE_KEY`, JWT) unchanged — see [SECURITY_SYSTEM.md](../03_Base/SECURITY_SYSTEM.md).
- **CI / unattended automation:** If GitHub Actions or another runner must touch prod, add a dedicated WireGuard peer for that runner or use a separate bastion — do not disable IP allowlisting.
- **Do not commit:** WireGuard private keys, `.env.prod`, or client `.conf` files.
- **Pipeline not final:** VPN + firewall are necessary but not sufficient; Phase 7 must produce a reviewed prod pipeline before this work is considered production-ready.

## Related

- [PRODUCTION_SYSTEM.md](../03_Base/PRODUCTION_SYSTEM.md)
- [SECURITY_SYSTEM.md](../03_Base/SECURITY_SYSTEM.md)
- [wfsecrets.md](../00_System_Wide/wfsecrets.md)
- [wfrun.md](../00_System_Wide/wfrun.md)
