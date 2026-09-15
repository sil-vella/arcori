"""Normalize free-form media maps for catalog JSON (goals, achievements, …).

Flat slots::

    "background": { "type": "image", "value": "/catalog-media/.../bg.webp" }

Post-completion group (multiple clips / anims) under ``post_task``::

    "post_task": {
      "animation": { "type": "lottie", "value": "/catalog-media/.../win.json" },
      "burst": { "type": "image", "value": "/catalog-media/.../burst.webp" },
      "sfx": { "type": "audio", "value": "/catalog-media/.../cheer.mp3" }
    }

Aliases ``post_achieve`` / ``post_goal`` normalize into ``post_task``.
``post_task`` may also be a list of ``{ key, type, value }`` entries.

Clients resolve root-relative ``value`` against the API host. Unknown slots /
types soft-ignore so new media ships without a Flutter rebuild.
"""

from __future__ import annotations

from typing import Any

# Soft allow-list for docs; unknown types are still passed through.
KNOWN_MEDIA_TYPES = frozenset(
    {
        "image",
        "lottie",
        "video",
        "audio",
        "svg",
    }
)

POST_TASK_KEY = "post_task"
_POST_TASK_ALIASES = frozenset({"post_task", "post_achieve", "post_goal", "postTask", "postAchieve", "postGoal"})


def _normalize_leaf(entry: Any) -> dict[str, str] | None:
    if not isinstance(entry, dict):
        return None
    # Nested group mistaken as leaf: has no type/value but nested dicts → not a leaf.
    media_type = str(
        entry.get("type") or entry.get("mediaType") or entry.get("media_type") or ""
    ).strip().lower()
    value = str(
        entry.get("value") or entry.get("url") or entry.get("path") or ""
    ).strip()
    if media_type and value:
        return {"type": media_type, "value": value}
    return None


def _normalize_post_task_group(raw: Any) -> dict[str, dict[str, str]]:
    """Map of named post-completion media slots."""
    out: dict[str, dict[str, str]] = {}
    if isinstance(raw, dict):
        # If it looks like a single leaf, store under default key "primary".
        leaf = _normalize_leaf(raw)
        if leaf is not None and not any(
            isinstance(v, (dict, list)) and _normalize_leaf(v) is not None
            for k, v in raw.items()
            if str(k) not in {"type", "mediaType", "media_type", "value", "url", "path"}
        ):
            # Pure leaf under post_task → wrap.
            if "type" in raw or "mediaType" in raw or "media_type" in raw:
                out["primary"] = leaf
                return out
        for key, entry in raw.items():
            slot = str(key or "").strip()
            if not slot:
                continue
            leaf = _normalize_leaf(entry)
            if leaf is None:
                continue
            out[slot] = leaf
        return out
    if isinstance(raw, list):
        for i, item in enumerate(raw):
            if not isinstance(item, dict):
                continue
            leaf = _normalize_leaf(item)
            if leaf is None:
                continue
            slot = str(item.get("key") or item.get("name") or f"item_{i}").strip()
            if not slot:
                slot = f"item_{i}"
            out[slot] = leaf
    return out


def normalize_media_map(raw: Any) -> dict[str, Any]:
    """
    Return media map:

    - flat slots → ``{ "type", "value" }``
    - ``post_task`` → ``{ slot: { "type", "value" }, ... }``
    """
    if not isinstance(raw, dict):
        return {}
    out: dict[str, Any] = {}
    post_task: dict[str, dict[str, str]] = {}

    for key, entry in raw.items():
        slot = str(key or "").strip()
        if not slot:
            continue
        if slot in _POST_TASK_ALIASES or slot.lower() in {
            "post_task",
            "post_achieve",
            "post_goal",
        }:
            group = _normalize_post_task_group(entry)
            for gkey, gval in group.items():
                # Later aliases merge; first wins on duplicate keys.
                if gkey not in post_task:
                    post_task[gkey] = gval
            continue
        leaf = _normalize_leaf(entry)
        if leaf is not None:
            out[slot] = leaf
            continue
        # Nested map that isn't post_task: treat as opaque group only if named
        # conventionally; otherwise skip.
        if isinstance(entry, dict):
            nested = _normalize_post_task_group(entry)
            if nested and not _normalize_leaf(entry):
                # Don't invent groups for random nested keys — only post_task.
                pass

    if post_task:
        out[POST_TASK_KEY] = post_task
    return out


def media_for_client(media: dict[str, Any] | None) -> dict[str, Any]:
    """Wire copy: flat leaves + nested ``post_task`` map (slot keys unchanged)."""
    if not media:
        return {}
    out: dict[str, Any] = {}
    for slot, row in media.items():
        if slot == POST_TASK_KEY and isinstance(row, dict):
            group = {
                k: {"type": v["type"], "value": v["value"]}
                for k, v in row.items()
                if isinstance(v, dict) and v.get("type") and v.get("value")
            }
            if group:
                out[POST_TASK_KEY] = group
            continue
        if isinstance(row, dict) and row.get("type") and row.get("value"):
            out[slot] = {"type": row["type"], "value": row["value"]}
    return out
