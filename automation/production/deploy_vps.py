#!/usr/bin/env python3
# dash Deploy Arcori stack to VPS (pull Hub images + compose up)
"""Copy compose/env/assets to the VPS and pull/up Hub images.

Requires wfrun/dashboard with WFRUN_MODE=prod. Does not install Docker —
Engine + Compose plugin and SSH docker group membership must already exist.

Edge: host nginx on api.arcori.app (dedicated vhost). Deploy prompts before
rewriting nginx (5s timeout, default skip). Type Y to ship body-size / edge conf.
Marketing arcori.app is left alone aside from removing any leftover backend snippet
include when nginx rewrite is chosen.

Prerequisites (on VPS): Docker Engine, Compose plugin, user in docker group,
DNS for api.arcori.app → this host. TLS via Certbot (deploy obtains the cert
on first run if missing).
"""

from __future__ import annotations

import os
import select
import subprocess
import sys
import time
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR.parent / "backend"))
from image_tag_env import Colors, require_wfrun_prod  # noqa: E402

COMPOSE_SRC = SCRIPT_DIR / "docker-compose.vps.yml"
NGINX_API_SITE_SRC = SCRIPT_DIR / "nginx-api.arcori.app.conf"
API_HOSTNAME = "api.arcori.app"

REQUIRED_VPS_KEYS = (
    "VPS_SSH_HOST",
    "VPS_SSH_USER",
    "VPS_SSH_KEY",
    "API_IMAGE_TAG",
    "DART_IMAGE_TAG",
)

CATALOG_SYNCS = (
    ("assets/images/arcori", "data/catalog-arcori"),
    ("assets/images/velora", "data/catalog-velora"),
    ("assets/lottie/kin", "data/catalog-kin"),
)


def _env(key: str, default: str = "") -> str:
    return (os.environ.get(key) or default).strip()


def _env_from_file(key: str, env_path: Path) -> str:
    """Read KEY from dotenv file (dashboard may have stale process env after build upserts)."""
    if not env_path.is_file():
        return ""
    for raw in env_path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[len("export ") :].lstrip()
        if not line.startswith(f"{key}="):
            continue
        val = line.split("=", 1)[1].strip()
        if len(val) >= 2 and val[0] == val[-1] and val[0] in "\"'":
            val = val[1:-1]
        return val.strip()
    return ""


def _require_keys(env_path: Path | None = None) -> None:
    missing: list[str] = []
    for k in REQUIRED_VPS_KEYS:
        # Image tags: .env.prod is SSOT after build_and_push_*. Prefer file over
        # a long-lived dashboard export that may still hold the previous tag.
        if env_path is not None and k in ("API_IMAGE_TAG", "DART_IMAGE_TAG"):
            from_file = _env_from_file(k, env_path)
            if from_file:
                prev = _env(k)
                os.environ[k] = from_file
                if prev and prev != from_file:
                    print(
                        f"{Colors.YELLOW}⚠ {k}: process env had {prev!r} — "
                        f"using {env_path.name}: {from_file}{Colors.NC}"
                    )
                elif not prev:
                    print(
                        f"{Colors.YELLOW}⚠ {k} not in process env — "
                        f"loaded from {env_path.name}: {from_file}{Colors.NC}"
                    )
                continue
        if _env(k):
            continue
        missing.append(k)
    if missing:
        print(
            f"{Colors.RED}❌ Missing or empty in exported env: "
            f"{', '.join(missing)}{Colors.NC}",
            file=sys.stderr,
        )
        if "API_IMAGE_TAG" in missing or "DART_IMAGE_TAG" in missing:
            print(
                f"{Colors.YELLOW}  Hint: run build_and_push_* first, or restart/"
                f"toggle dashboard prod so .env.prod is reloaded.{Colors.NC}",
                file=sys.stderr,
            )
        sys.exit(1)


def _ssh_base() -> list[str]:
    key = _env("VPS_SSH_KEY")
    key_path = Path(key).expanduser()
    if not key_path.is_file():
        print(f"{Colors.RED}❌ SSH key not found: {key_path}{Colors.NC}", file=sys.stderr)
        sys.exit(1)
    return [
        "ssh",
        "-i",
        str(key_path),
        "-o",
        "StrictHostKeyChecking=accept-new",
        "-o",
        "BatchMode=yes",
    ]


def _ssh_target() -> str:
    return f"{_env('VPS_SSH_USER')}@{_env('VPS_SSH_HOST')}"


def _run(cmd: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    print(f"  $ {' '.join(cmd)}")
    return subprocess.run(cmd, check=check, text=True, capture_output=False)


def _ssh(remote_cmd: str, *, check: bool = True) -> subprocess.CompletedProcess[str]:
    cmd = _ssh_base() + [_ssh_target(), remote_cmd]
    return _run(cmd, check=check)


def _scp(local: Path, remote_path: str) -> None:
    key = str(Path(_env("VPS_SSH_KEY")).expanduser())
    cmd = [
        "scp",
        "-i",
        key,
        "-o",
        "StrictHostKeyChecking=accept-new",
        "-o",
        "BatchMode=yes",
        str(local),
        f"{_ssh_target()}:{remote_path}",
    ]
    _run(cmd)


def _rsync(local_dir: Path, remote_rel: str, app_root: str) -> None:
    if not local_dir.is_dir():
        print(
            f"{Colors.YELLOW}⚠ Skip rsync (missing locally): {local_dir}{Colors.NC}"
        )
        return
    key = str(Path(_env("VPS_SSH_KEY")).expanduser())
    remote = f"{_ssh_target()}:{app_root}/{remote_rel}/"
    cmd = [
        "rsync",
        "-az",
        "--delete",
        "-e",
        f"ssh -i {key} -o StrictHostKeyChecking=accept-new -o BatchMode=yes",
        f"{local_dir}/",
        remote,
    ]
    _run(cmd)


def _docker_wrap(app_user: str, inner: str) -> str:
    if app_user == "root":
        return inner
    escaped = inner.replace("'", "'\"'\"'")
    return f"sg docker -c '{escaped}'"


def _confirm_deploy() -> bool:
    if sys.stdin.isatty():
        response = input("Proceed with VPS deploy (pull + up)? (y/n): ").strip().lower()
        if response != "y":
            print(f"{Colors.YELLOW}Deploy cancelled.{Colors.NC}")
            return False
        return True
    print("Non-interactive mode: Auto-confirming VPS deploy...")
    return True


def _wait_health(app_user: str, timeout_s: int = 120) -> bool:
    print(f"\n{Colors.BLUE}Waiting for container health (up to {timeout_s}s)...{Colors.NC}")
    deadline = time.time() + timeout_s
    services = ("Arcori_api", "Arcori_dart")
    while time.time() < deadline:
        statuses: dict[str, str] = {}
        all_ok = True
        for svc in services:
            inner = (
                f"docker inspect --format="
                f"'{{{{if .State.Health}}}}{{{{.State.Health.Status}}}}"
                f"{{{{else}}}}{{{{.State.Status}}}}{{{{end}}}}' {svc} 2>/dev/null || echo missing"
            )
            wrapped = _docker_wrap(app_user, inner)
            result = subprocess.run(
                _ssh_base() + [_ssh_target(), wrapped],
                check=False,
                text=True,
                capture_output=True,
            )
            status = (result.stdout or "").strip() or "unknown"
            statuses[svc] = status
            if status != "healthy":
                all_ok = False
        print("  " + ", ".join(f"{s}={statuses[s]}" for s in services))
        if all_ok:
            print(f"{Colors.GREEN}✓ API and Dart containers healthy{Colors.NC}")
            return True
        time.sleep(5)
    print(f"{Colors.RED}✗ Health wait timed out{Colors.NC}", file=sys.stderr)
    return False


def _prompt_nginx_rewrite(*, timeout_s: float = 5.0) -> bool:
    """Ask to rewrite nginx; default skip on timeout / non-interactive."""
    prompt = (
        f"Rewrite nginx {API_HOSTNAME} config? "
        f"[y=rewrite / N=skip] ({timeout_s:.0f}s, default skip): "
    )
    print(f"\n{Colors.BLUE}Nginx edge (optional)...{Colors.NC}")
    print(prompt, end="", flush=True)
    if not sys.stdin.isatty():
        print("skip (non-interactive)")
        return False
    ready, _, _ = select.select([sys.stdin], [], [], timeout_s)
    if not ready:
        print("skip (timeout)")
        return False
    response = sys.stdin.readline().strip().lower()
    if response in ("y", "yes"):
        print("rewrite")
        return True
    print("skip")
    return False


def _install_nginx_api_vhost() -> None:
    """Install api.arcori.app site; strip leftover backend include from arcori.app."""
    print(f"\n{Colors.BLUE}Installing nginx {API_HOSTNAME} vhost...{Colors.NC}")
    if not NGINX_API_SITE_SRC.is_file():
        print(f"{Colors.RED}❌ Missing {NGINX_API_SITE_SRC}{Colors.NC}", file=sys.stderr)
        sys.exit(1)

    remote_tmp = "/tmp/nginx-api.arcori.app.conf"
    _scp(NGINX_API_SITE_SRC, remote_tmp)

    # Touch only api.arcori.app + clean marketing arcori.app (not dutch/other).
    # Use ''' for remote script body so nested nginx conf can use """.
    remote_py = '''
import pathlib, subprocess, sys

HOST = "api.arcori.app"
site_src = pathlib.Path("/tmp/nginx-api.arcori.app.conf")
site_dst = pathlib.Path("/etc/nginx/sites-available") / HOST
enabled = pathlib.Path("/etc/nginx/sites-enabled") / HOST
cert = pathlib.Path(f"/etc/letsencrypt/live/{HOST}/fullchain.pem")
marketing = pathlib.Path("/etc/nginx/sites-available/arcori.app")
snippet = pathlib.Path("/etc/nginx/snippets/arcori-backend.conf")

# --- marketing: remove path-based backend include ---
if marketing.is_file():
    text = marketing.read_text(encoding="utf-8")
    original = text.splitlines(keepends=True)
    lines = [
        ln for ln in original if "snippets/arcori-backend.conf" not in ln
    ]
    if lines != original:
        marketing.write_text("".join(lines), encoding="utf-8")
        print("removed backend include from", marketing)
    else:
        print("arcori.app has no backend include")
else:
    print("WARN: missing", marketing)

if snippet.is_file():
    snippet.unlink()
    print("deleted", snippet)

# --- ensure TLS cert ---
if not cert.is_file():
    bootstrap = f"""
server {{
    listen 80;
    listen [::]:80;
    server_name {HOST};
    location / {{
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }}
}}
"""
    site_dst.write_text(bootstrap, encoding="utf-8")
    if enabled.exists() or enabled.is_symlink():
        enabled.unlink()
    enabled.symlink_to(site_dst)
    r = subprocess.run(["nginx", "-t"], check=False)
    if r.returncode != 0:
        print("ERROR: nginx -t failed on HTTP bootstrap", file=sys.stderr)
        sys.exit(1)
    subprocess.run(["systemctl", "reload", "nginx"], check=True)
    print("HTTP bootstrap active; requesting Certbot cert for", HOST)
    r = subprocess.run(
        [
            "certbot",
            "certonly",
            "--nginx",
            "-d",
            HOST,
            "--non-interactive",
            "--agree-tos",
            "--keep-until-expiring",
        ],
        check=False,
    )
    if r.returncode != 0 or not cert.is_file():
        print(
            "ERROR: Certbot failed for",
            HOST,
            "- fix DNS/email then re-run deploy",
            file=sys.stderr,
        )
        sys.exit(1)
    print("obtained cert", cert)

# --- install managed SSL site ---
site_dst.write_text(site_src.read_text(encoding="utf-8"), encoding="utf-8")
print("wrote", site_dst)
if enabled.exists() or enabled.is_symlink():
    enabled.unlink()
enabled.symlink_to(site_dst)
print("enabled", enabled)

r = subprocess.run(["nginx", "-t"], check=False)
if r.returncode != 0:
    print("ERROR: nginx -t failed after installing", HOST, file=sys.stderr)
    sys.exit(1)
subprocess.run(["systemctl", "reload", "nginx"], check=True)
print("nginx", HOST, "active")
'''
    _ssh(
        "cat > /tmp/arcori_nginx_api_install.py << 'PY'\n"
        + remote_py
        + "\nPY\n"
        "sudo python3 /tmp/arcori_nginx_api_install.py"
    )
    print(f"{Colors.GREEN}✓ nginx {API_HOSTNAME} active (marketing cleaned){Colors.NC}")


def main() -> None:
    print(f"{Colors.BLUE}=== Arcori VPS Deploy (pull + up) ==={Colors.NC}\n")

    project_root, env_path = require_wfrun_prod()
    _require_keys(env_path)

    if not COMPOSE_SRC.is_file():
        print(f"{Colors.RED}❌ Missing {COMPOSE_SRC}{Colors.NC}", file=sys.stderr)
        sys.exit(1)

    app_root = _env("APP_ROOT", "/opt/apps/arcori")
    app_user = _env("VPS_SSH_USER")
    api_tag = _env("API_IMAGE_TAG")
    dart_tag = _env("DART_IMAGE_TAG")
    docker_user = _env("DOCKER_USERNAME", "silvella")

    print(f"{Colors.BLUE}Configuration:{Colors.NC}")
    print(f"  SSH:        {_ssh_target()}")
    print(f"  APP_ROOT:   {app_root}")
    print(f"  Env file:   {env_path}")
    print(f"  API image:  {docker_user}/arcori_api:{api_tag}")
    print(f"  Dart image: {docker_user}/arcori_dart:{dart_tag}")
    print(f"  Edge:       nginx {API_HOSTNAME} (dedicated; no Caddy)")
    print(f"  Localhost:  API :8000  Dart :8085")
    print()

    if not _confirm_deploy():
        sys.exit(0)

    from image_tag_env import upsert_env_key
    from urllib.parse import quote

    upsert_env_key(env_path, "APP_ROOT", app_root)
    upsert_env_key(env_path, "API_IMAGE_TAG", api_tag)
    upsert_env_key(env_path, "DART_IMAGE_TAG", dart_tag)
    if docker_user:
        upsert_env_key(env_path, "DOCKER_USERNAME", docker_user)

    # Compose builds postgresql://… URLs; encode passwords so %/@/: etc. are safe.
    owner_pw = _env("POSTGRES_PASSWORD") or _env_from_file("POSTGRES_PASSWORD", env_path)
    app_pw = _env("POSTGRES_APP_PASSWORD") or _env_from_file(
        "POSTGRES_APP_PASSWORD", env_path
    )
    if not owner_pw or not app_pw:
        print(
            f"{Colors.RED}❌ POSTGRES_PASSWORD and POSTGRES_APP_PASSWORD required"
            f"{Colors.NC}",
            file=sys.stderr,
        )
        sys.exit(1)
    upsert_env_key(env_path, "POSTGRES_PASSWORD_URLENC", quote(owner_pw, safe=""))
    upsert_env_key(env_path, "POSTGRES_APP_PASSWORD_URLENC", quote(app_pw, safe=""))

    print(f"\n{Colors.BLUE}Creating remote directories...{Colors.NC}")
    dirs = [
        app_root,
        f"{app_root}/docker",
        f"{app_root}/data/postgres",
        f"{app_root}/data/postgres/pgdata",
        f"{app_root}/data/postgres/tls",
        f"{app_root}/data/redis",
        f"{app_root}/data/uploads",
        f"{app_root}/data/catalog-arcori",
        f"{app_root}/data/catalog-velora",
        f"{app_root}/data/catalog-kin",
    ]
    # /opt/apps is root-owned on rop01; create + chown like Ansible become.
    _ssh(
        f"sudo mkdir -p {' '.join(dirs)} && "
        f"sudo chown -R {app_user}:{app_user} {app_root}"
    )
    # Official postgres:16 runs as uid/gid 999 — only the empty PGDATA dir.
    _ssh(f"sudo chown -R 999:999 {app_root}/data/postgres/pgdata")

    print(f"\n{Colors.BLUE}Copying .env + compose...{Colors.NC}")
    _scp(env_path, f"{app_root}/.env")
    _ssh(f"chmod 0600 {app_root}/.env")
    _scp(COMPOSE_SRC, f"{app_root}/docker/docker-compose.yml")

    print(f"\n{Colors.BLUE}Syncing catalog assets...{Colors.NC}")
    for local_rel, remote_rel in CATALOG_SYNCS:
        _rsync(project_root / local_rel, remote_rel, app_root)

    compose_cd = f"cd {app_root}/docker"
    env_arg = f"--env-file {app_root}/.env"
    compose_f = "-f docker-compose.yml"

    print(f"\n{Colors.BLUE}Validating compose config...{Colors.NC}")
    validate = _docker_wrap(
        app_user,
        f"{compose_cd} && docker compose {env_arg} {compose_f} config -q",
    )
    result = _ssh(validate, check=False)
    if result.returncode != 0:
        print(
            f"{Colors.RED}✗ docker compose config -q failed "
            f"(syntax or .env interpolation).{Colors.NC}",
            file=sys.stderr,
        )
        sys.exit(1)
    print(f"{Colors.GREEN}✓ Compose file validated{Colors.NC}")

    print(f"\n{Colors.BLUE}Pulling images...{Colors.NC}")
    _ssh(
        _docker_wrap(
            app_user,
            f"{compose_cd} && docker compose {env_arg} {compose_f} pull",
        )
    )

    print(f"\n{Colors.BLUE}Starting stack (up -d)...{Colors.NC}")
    _ssh(
        _docker_wrap(
            app_user,
            f"{compose_cd} && docker compose {env_arg} {compose_f} up -d",
        )
    )

    healthy = _wait_health(app_user)
    if not healthy:
        print(
            f"{Colors.YELLOW}Inspect: ssh {_ssh_target()} "
            f"'cd {app_root}/docker && docker compose logs Arcori_api Arcori_dart'"
            f"{Colors.NC}"
        )
        sys.exit(1)

    if _prompt_nginx_rewrite():
        _install_nginx_api_vhost()
    else:
        print(
            f"{Colors.YELLOW}⏭ Skipped nginx rewrite "
            f"(existing {API_HOSTNAME} left as-is){Colors.NC}"
        )

    print(f"\n{Colors.BLUE}Pruning unused images...{Colors.NC}")
    _ssh(_docker_wrap(app_user, "docker image prune -a -f"))

    tag_content = f"API_IMAGE_TAG={api_tag}\nDART_IMAGE_TAG={dart_tag}\n"
    escaped = tag_content.replace("'", "'\"'\"'")
    _ssh(
        f"printf '%s' '{escaped}' > {app_root}/.deployed_image_tag && "
        f"chmod 0644 {app_root}/.deployed_image_tag"
    )
    print(f"{Colors.GREEN}✓ Recorded {app_root}/.deployed_image_tag{Colors.NC}")

    print(f"\n{Colors.GREEN}=== DEPLOYMENT COMPLETE ==={Colors.NC}")
    print(f"  App root: {app_root}")
    print(f"  API:  {docker_user}/arcori_api:{api_tag}  → 127.0.0.1:8000")
    print(f"  Dart: {docker_user}/arcori_dart:{dart_tag} → 127.0.0.1:8085")
    print(f"  Public: https://{API_HOSTNAME}  (nginx dedicated vhost)")
    print(f"  Marketing: https://arcori.app  (no API paths)")
    print(f"  Check:  curl -sf https://{API_HOSTNAME}/health")
    print(f"  Dart:   curl -sf https://{API_HOSTNAME}/game/health")
    print()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n{Colors.YELLOW}Interrupted.{Colors.NC}")
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        print(f"\n{Colors.RED}Command failed (exit {e.returncode}){Colors.NC}")
        sys.exit(e.returncode or 1)
