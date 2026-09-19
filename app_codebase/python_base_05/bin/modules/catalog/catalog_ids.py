"""Arcori internalId / serial helpers — SER = series, GEN = generation."""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any

# THEME-CODE-SERnnn-GENnnn-####  (GEN optional on legacy ids during cutover)
_ID_RE = re.compile(
    r"^(?P<theme>[A-Z0-9]+)-(?P<code>[A-Z0-9]+)-"
    r"(?P<ser>SER\d{3})"
    r"(?:-(?P<gen>GEN\d{3}))?"
    r"-(?P<seq>\d+)$",
    re.IGNORECASE,
)

_SERIES_NAMES = {
    0: "Creation",
    1: "Genesis",
    2: "Pioneers",
    3: "Foundations",
    4: "Civilizations",
}

_ROMAN = {
    1: "I",
    2: "II",
    3: "III",
    4: "IV",
    5: "V",
    6: "VI",
    7: "VII",
    8: "VIII",
    9: "IX",
    10: "X",
    11: "XI",
    12: "XII",
}


@dataclass(frozen=True)
class ParsedDesignId:
    theme_code: str
    design_code: str
    ser_token: str
    series_number: int
    gen_token: str | None
    generation_number: int
    seq: str
    raw: str

    @property
    def has_gen(self) -> bool:
        return self.gen_token is not None


def roman_for(generation_number: int) -> str:
    n = int(generation_number)
    if n in _ROMAN:
        return _ROMAN[n]
    return str(n)


def series_name_for_ser_number(ser_number: int) -> str:
    return _SERIES_NAMES.get(int(ser_number), f"SER{int(ser_number):03d}")


def parse_design_id(internal_id: str) -> ParsedDesignId | None:
    raw = (internal_id or "").strip()
    if not raw:
        return None
    m = _ID_RE.match(raw)
    if m is None:
        return None
    ser = m.group("ser").upper()
    gen = m.group("gen")
    gen_token = gen.upper() if gen else None
    try:
        series_number = int(ser[3:])
    except ValueError:
        series_number = 0
    if gen_token:
        try:
            generation_number = int(gen_token[3:])
        except ValueError:
            generation_number = 1
    else:
        generation_number = 1
    return ParsedDesignId(
        theme_code=m.group("theme").upper(),
        design_code=m.group("code").upper(),
        ser_token=ser,
        series_number=series_number,
        gen_token=gen_token,
        generation_number=generation_number,
        seq=m.group("seq"),
        raw=raw,
    )


def format_design_id(
    *,
    theme_code: str,
    design_code: str,
    ser_token: str,
    generation_number: int,
    seq: str,
) -> str:
    gen = int(generation_number)
    return (
        f"{theme_code.strip().upper()}-"
        f"{design_code.strip().upper()}-"
        f"{ser_token.strip().upper()}-"
        f"GEN{gen:03d}-"
        f"{seq.strip()}"
    )


def with_generation(internal_id: str, generation_number: int) -> str:
    """Rewrite or insert GENnnn for the given generation number."""
    parsed = parse_design_id(internal_id)
    if parsed is None:
        raise ValueError(f"Unparseable design id: {internal_id!r}")
    return format_design_id(
        theme_code=parsed.theme_code,
        design_code=parsed.design_code,
        ser_token=parsed.ser_token,
        generation_number=generation_number,
        seq=parsed.seq,
    )


def ensure_gen001(internal_id: str) -> str:
    """If id lacks GEN, insert GEN001; otherwise return unchanged (normalized)."""
    parsed = parse_design_id(internal_id)
    if parsed is None:
        raise ValueError(f"Unparseable design id: {internal_id!r}")
    if parsed.has_gen:
        return with_generation(parsed.raw, parsed.generation_number)
    return with_generation(parsed.raw, 1)


def art_basename(internal_id: str) -> str:
    """Filename stem for :ro art — strip GENnnn so echoes reuse GEN001 webp."""
    parsed = parse_design_id(internal_id)
    if parsed is None:
        return (internal_id or "").strip()
    return (
        f"{parsed.theme_code}-{parsed.design_code}-"
        f"{parsed.ser_token}-{parsed.seq}"
    )


def design_id_aliases(internal_id: str) -> list[str]:
    """Canonical + legacy id forms for the same piece/generation.

    Cutover left both ``THEME-CODE-SERnnn-####`` and ``…-GENnnn-####`` in play.
    Close / access / select must treat them as one design.
    """
    raw = (internal_id or "").strip()
    if not raw:
        return []
    out: list[str] = []
    seen: set[str] = set()

    def _add(value: str) -> None:
        text = (value or "").strip()
        if not text or text in seen:
            return
        seen.add(text)
        out.append(text)

    _add(raw)
    try:
        _add(art_basename(raw))
    except Exception:
        pass
    try:
        _add(ensure_gen001(raw))
    except Exception:
        pass
    try:
        parsed = parse_design_id(raw)
        if parsed is not None:
            _add(with_generation(raw, parsed.generation_number))
    except Exception:
        pass
    return out


def generation_number_from_id(internal_id: str, default: int = 1) -> int:
    parsed = parse_design_id(internal_id)
    if parsed is None:
        return default
    return parsed.generation_number


def family_key(internal_id: str) -> str | None:
    """Stable family without GEN: THEME-CODE-SERnnn-####."""
    parsed = parse_design_id(internal_id)
    if parsed is None:
        return None
    return art_basename(internal_id)


def apply_generation_to_design_doc(
    design: dict[str, Any],
    *,
    generation_number: int,
    creator: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Deep-ish copy design with new internalId + generation fields."""
    import copy

    out = copy.deepcopy(design)
    old_id = str(out.get("internalId") or "").strip()
    if not old_id:
        raise ValueError("design missing internalId")
    new_id = with_generation(old_id, generation_number)
    out["internalId"] = new_id
    gen_block = out.get("generation")
    if not isinstance(gen_block, dict):
        gen_block = {}
    else:
        gen_block = dict(gen_block)
    gen_block["number"] = int(generation_number)
    gen_block["roman"] = roman_for(generation_number)
    if creator is not None:
        gen_block["creator"] = creator
    out["generation"] = gen_block
    return out
