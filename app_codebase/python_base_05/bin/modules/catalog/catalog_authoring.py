"""Catalog file scan helpers — authoring JSON only (import script / seed)."""

from __future__ import annotations

from typing import Any

from modules.catalog import catalog_loader as loader
from modules.catalog.catalog_ids import ensure_gen001


def iter_authored_designs() -> list[dict[str, Any]]:
    """Flatten theme JSON designs with series_key + catalog_version."""
    out: list[dict[str, Any]] = []
    for doc in loader.list_theme_documents():
        designs = doc.get("designs")
        if not isinstance(designs, list):
            continue
        series_key = str(doc.get("series") or "").strip() or "Unknown"
        version = doc.get("version")
        try:
            catalog_version = int(version) if version is not None else None
        except (TypeError, ValueError):
            catalog_version = None
        doc_theme = str(doc.get("theme") or "")
        doc_theme_code = str(doc.get("themeCode") or "")
        for design in designs:
            if not isinstance(design, dict):
                continue
            payload = dict(design)
            iid = str(payload.get("internalId") or "").strip()
            if not iid:
                continue
            try:
                payload["internalId"] = ensure_gen001(iid)
            except ValueError:
                continue
            if not payload.get("theme"):
                payload["theme"] = doc_theme
            if not payload.get("themeCode"):
                payload["themeCode"] = doc_theme_code
            out.append(
                {
                    "design": payload,
                    "series_key": series_key,
                    "catalog_version": catalog_version,
                }
            )
    return out
