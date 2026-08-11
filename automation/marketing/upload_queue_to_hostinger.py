#!/usr/bin/env python3
# dash Upload local campaign video_* dirs to Hostinger marketing queue
"""Sync local marketing campaign videos → Hostinger product queue.

Reads REPO_BRAND + MARKETING_LOCAL_DIR from env (via wfrun).

1. SSH (alias mixta_mt) → ~/rop01/marketing/<REPO_BRAND>/videos/
2. Find last remote video_*** (or last successful video from product logs if empty)
3. Locally find that video under campaign_***; upload all *following* video_*
   dirs (same campaign + later campaigns)
4. If no local match: interactive browse MARKETING_LOCAL_DIR → pick start
   video_* (that one + all following are uploaded)

Usage:
  wfrun → automation/marketing/upload_queue_to_hostinger.py
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

from publish_common import env, prompt_yes_no, require_wfrun

SSH_HOST = "mixta_mt"
REMOTE_MARKETING = "/home/u877877481/rop01/marketing"

VIDEO_RE = re.compile(r"^video_(\d+)$")
CAMPAIGN_RE = re.compile(r"^campaign_(\d+)$")
LOG_VIDEO_RE = re.compile(r"\b(video_\d+)\b")

# Skip editor junk when uploading a video_* tree
RSYNC_EXCLUDES = (
    ".DS_Store",
    "Adobe Premiere Pro Auto-Save",
    "Adobe Premiere Pro Audio Previews",
    "Thumbs.db",
)


def _die(msg: str, code: int = 1) -> None:
    print(f"❌ {msg}", file=sys.stderr)
    raise SystemExit(code)


def _ssh(remote_cmd: str, *, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=20", SSH_HOST, remote_cmd],
        check=check,
        text=True,
        capture_output=True,
    )


def _video_index(name: str) -> int | None:
    m = VIDEO_RE.match(name)
    return int(m.group(1)) if m else None


def _campaign_index(name: str) -> int | None:
    m = CAMPAIGN_RE.match(name)
    return int(m.group(1)) if m else None


def _sorted_video_dirs(parent: Path) -> list[Path]:
    found: list[tuple[int, Path]] = []
    if not parent.is_dir():
        return []
    for child in parent.iterdir():
        if not child.is_dir():
            continue
        idx = _video_index(child.name)
        if idx is not None:
            found.append((idx, child))
    found.sort(key=lambda t: t[0])
    return [p for _, p in found]


def _sorted_campaign_dirs(root: Path) -> list[Path]:
    found: list[tuple[int, Path]] = []
    if not root.is_dir():
        return []
    for child in root.iterdir():
        if not child.is_dir():
            continue
        idx = _campaign_index(child.name)
        if idx is not None:
            found.append((idx, child))
    found.sort(key=lambda t: t[0])
    return [p for _, p in found]


def _all_campaign_video_slots(root: Path) -> list[tuple[Path, Path]]:
    """Ordered (campaign_dir, video_dir) for campaign_*** / video_*** only."""
    slots: list[tuple[Path, Path]] = []
    for campaign in _sorted_campaign_dirs(root):
        for video in _sorted_video_dirs(campaign):
            slots.append((campaign, video))
    return slots


def _find_anchor_index(slots: list[tuple[Path, Path]], video_name: str) -> int | None:
    """Last slot whose video folder name matches (prefer later campaigns)."""
    last: int | None = None
    for i, (_c, v) in enumerate(slots):
        if v.name == video_name:
            last = i
    return last


def _slots_after(
    slots: list[tuple[Path, Path]],
    video_name: str,
    *,
    include_anchor: bool,
) -> list[tuple[Path, Path]]:
    idx = _find_anchor_index(slots, video_name)
    if idx is None:
        return []
    start = idx if include_anchor else idx + 1
    return slots[start:]


def _list_remote_video_names(product: str) -> list[str]:
    remote_videos = f"{REMOTE_MARKETING}/{product}/videos"
    proc = _ssh(f"mkdir -p {remote_videos!s} {REMOTE_MARKETING}/logs; ls -1 {remote_videos}", check=False)
    if proc.returncode != 0:
        err = (proc.stderr or proc.stdout or "").strip()
        _die(f"ssh {SSH_HOST} failed listing videos: {err or proc.returncode}")
    names: list[tuple[int, str]] = []
    for line in (proc.stdout or "").splitlines():
        name = line.strip()
        idx = _video_index(name)
        if idx is not None:
            names.append((idx, name))
    names.sort(key=lambda t: t[0])
    return [n for _, n in names]


def _last_successful_video_from_logs(product: str) -> str | None:
    """Parse newest *_{product}.log files for a video_*** mention."""
    logs = f"{REMOTE_MARKETING}/logs"
    proc = _ssh(
        f"ls -1t {logs}/*_{product}.log 2>/dev/null | head -20",
        check=False,
    )
    paths = [ln.strip() for ln in (proc.stdout or "").splitlines() if ln.strip()]
    if not paths:
        return None
    # Read a few newest logs remotely (cat)
    for path in paths:
        read = _ssh(f"cat {path!s}", check=False)
        if read.returncode != 0:
            continue
        body = read.stdout or ""
        # Prefer explicit success markers; else last video_* token in file
        success_lines = [
            ln
            for ln in body.splitlines()
            if re.search(r"success|posted|ok\b", ln, re.I)
        ]
        search_blob = "\n".join(success_lines) if success_lines else body
        matches = LOG_VIDEO_RE.findall(search_blob)
        if matches:
            return matches[-1]
    return None


def _interactive_pick_start(root: Path) -> tuple[Path, Path] | None:
    """Browse MARKETING_LOCAL_DIR → campaign/folder → video_*. Returns (parent, video)."""
    cwd = root.resolve()
    while True:
        entries = sorted(
            [p for p in cwd.iterdir() if p.is_dir() and not p.name.startswith(".")],
            key=lambda p: p.name.lower(),
        )
        print()
        print(f"📂 {cwd}")
        if cwd != root.resolve():
            print("  0) .. (go up)")
        if not entries:
            print("  (empty)")
        for i, p in enumerate(entries, start=1):
            mark = ""
            if _campaign_index(p.name) is not None:
                mark = " [campaign]"
            elif _sorted_video_dirs(p):
                mark = " [has video_*]"
            print(f"  {i}) {p.name}{mark}")
        print("  q) quit")

        raw = input("Choose: ").strip().lower()
        if raw in {"q", "quit"}:
            return None
        if raw in {"0", ".."} and cwd != root.resolve():
            cwd = cwd.parent
            continue
        if not raw.isdigit():
            print("Enter a number.")
            continue
        n = int(raw)
        if n < 1 or n > len(entries):
            print("Out of range.")
            continue
        chosen = entries[n - 1]
        videos = _sorted_video_dirs(chosen)
        if videos:
            print()
            print(f"Videos in {chosen.name}:")
            print("  0) .. (back)")
            for i, v in enumerate(videos, start=1):
                print(f"  {i}) {v.name}")
            print("  e) enter this dir (no video pick yet)")
            sub = input("Choose video (or e): ").strip().lower()
            if sub in {"0", "..", "b", "back"}:
                continue
            if sub in {"e", "enter"}:
                cwd = chosen
                continue
            if not sub.isdigit():
                print("Enter a number.")
                continue
            vi = int(sub)
            if vi < 1 or vi > len(videos):
                print("Out of range.")
                continue
            return chosen, videos[vi - 1]
        cwd = chosen


def _following_from_pick(
    root: Path, parent: Path, video: Path
) -> list[tuple[Path, Path]]:
    """Chosen video + following video_* in campaign_* sequence.

    If parent is campaign_N, use global campaign/video order from that point.
    Otherwise: video + higher video_* in same parent only, then all campaign_* videos.
    """
    slots = _all_campaign_video_slots(root)
    if _campaign_index(parent.name) is not None:
        # include chosen
        out = _slots_after(slots, video.name, include_anchor=True)
        # If same video name in earlier campaign matched, ensure we start at this parent
        refined: list[tuple[Path, Path]] = []
        started = False
        for c, v in slots:
            if not started:
                if c.resolve() == parent.resolve() and v.name == video.name:
                    started = True
                    refined.append((c, v))
                continue
            refined.append((c, v))
        return refined if started else out

    # Non-campaign parent (e.g. init_campaign)
    local_videos = _sorted_video_dirs(parent)
    start_i = next((i for i, v in enumerate(local_videos) if v.name == video.name), None)
    if start_i is None:
        return [(parent, video)]
    result: list[tuple[Path, Path]] = [(parent, v) for v in local_videos[start_i:]]
    # Then all campaign_* videos
    result.extend(slots)
    return result


def _upload_video_dir(local_video: Path, product: str) -> None:
    remote_dest = f"{REMOTE_MARKETING}/{product}/videos/"
    rsync = shutil.which("rsync")
    if rsync:
        cmd = [
            rsync,
            "-a",
            "--delete",
            *[f"--exclude={x}" for x in RSYNC_EXCLUDES],
            f"{local_video}/",
            f"{SSH_HOST}:{remote_dest}{local_video.name}/",
        ]
    else:
        # scp cannot exclude; copy whole tree
        cmd = ["scp", "-r", str(local_video), f"{SSH_HOST}:{remote_dest}"]
    print(f"↑ {local_video.parent.name}/{local_video.name} → {remote_dest}{local_video.name}/")
    proc = subprocess.run(cmd, text=True, capture_output=True)
    if proc.returncode != 0:
        err = (proc.stderr or proc.stdout or "").strip()
        _die(f"upload failed for {local_video.name}: {err or proc.returncode}")


def main() -> int:
    require_wfrun()

    product = env("REPO_BRAND") or os.environ.get("REPO_BRAND", "").strip()
    local_root_s = env("MARKETING_LOCAL_DIR") or os.environ.get("MARKETING_LOCAL_DIR", "").strip()
    if not product:
        _die("REPO_BRAND is empty — set it in .env.local")
    if not re.fullmatch(r"[A-Za-z0-9_-]+", product):
        _die(f"REPO_BRAND must be a safe folder name [A-Za-z0-9_-]+, got: {product!r}")
    if not local_root_s:
        _die("MARKETING_LOCAL_DIR is empty — set it in .env.local")

    local_root = Path(local_root_s).expanduser()
    if not local_root.is_dir():
        _die(f"MARKETING_LOCAL_DIR is not a directory: {local_root}")

    print(f"Product (REPO_BRAND): {product}")
    print(f"Local marketing dir:  {local_root}")
    print(f"Remote queue:         {SSH_HOST}:{REMOTE_MARKETING}/{product}/videos/")
    print()

    remote_videos = _list_remote_video_names(product)
    anchor_name: str | None = None
    include_anchor = False
    mode = "auto"

    if remote_videos:
        anchor_name = remote_videos[-1]
        print(f"Remote last video_***: {anchor_name} ({len(remote_videos)} on Hostinger)")
    else:
        print("Remote videos/ is empty — checking product logs for last successful video…")
        anchor_name = _last_successful_video_from_logs(product)
        if anchor_name:
            print(f"Last successful from logs: {anchor_name}")
        else:
            print("No log anchor found.")

    slots = _all_campaign_video_slots(local_root)
    to_upload: list[tuple[Path, Path]] = []

    if anchor_name:
        to_upload = _slots_after(slots, anchor_name, include_anchor=False)
        if not to_upload and _find_anchor_index(slots, anchor_name) is None:
            print(f"No local campaign_*** match for {anchor_name} — interactive pick.")
            mode = "interactive"
        elif not to_upload:
            print(f"Nothing after {anchor_name} under local campaign_*** dirs.")
            return 0
        else:
            print(f"Will upload {len(to_upload)} dir(s) after {anchor_name}.")
    else:
        mode = "interactive"

    if mode == "interactive":
        print("Interactive: choose a starting video_*** (it will be included).")
        picked = _interactive_pick_start(local_root)
        if not picked:
            print("Cancelled.")
            return 0
        parent, video = picked
        include_anchor = True
        to_upload = _following_from_pick(local_root, parent, video)
        if not to_upload:
            _die("Nothing to upload after interactive pick.")
        print(f"Will upload {len(to_upload)} dir(s) starting at {parent.name}/{video.name}.")

    print()
    for c, v in to_upload:
        print(f"  - {c.name}/{v.name}")
    print()

    if not prompt_yes_no("Upload these folders to Hostinger?", default_yes=True):
        print("Cancelled.")
        return 0

    _ssh(f"mkdir -p {REMOTE_MARKETING}/{product}/videos {REMOTE_MARKETING}/logs", check=True)

    for c, v in to_upload:
        if not v.is_dir():
            _die(f"missing local dir: {v}")
        _upload_video_dir(v, product)

    print()
    print(f"✅ Uploaded {len(to_upload)} video dir(s) for product {product}.")
    if include_anchor:
        print("(interactive start included)")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as exc:
        err = ""
        if isinstance(exc.stderr, str):
            err = exc.stderr.strip()
        _die(f"command failed: {err or exc}")
    except KeyboardInterrupt:
        print("\nCancelled.", file=sys.stderr)
        raise SystemExit(130)
