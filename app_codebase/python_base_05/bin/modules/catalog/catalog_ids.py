"""Arcori / Slammer / Kin internalId helpers.

Canonical wire form:
  ``{TYPE}-{THEME}-{CODE}-SERnnn-GENnnn-####``
  e.g. ``ARC-ANM-TIG-SER001-GEN001-0001``
       ``SLM-SLM-STR-SER001-GEN001-0001``

Kin (player mint) keeps a long code token:
  ``KIN-KIN-{TOKEN}-SERnnn-GENnnn-####`` after unify, or legacy
  ``KIN-{TOKEN}-SERnnn-GENnnn-####`` (TYPE implied by leading KIN).

Art files stay on the pre-TYPE, pre-GEN basename (``ANM-TIG-SER001-0001.webp``).
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any

TYPE_ARC = "ARC"
TYPE_SLM = "SLM"
TYPE_KIN = "KIN"
KNOWN_TYPES = frozenset({TYPE_ARC, TYPE_SLM, TYPE_KIN})

# TYPE-THEME-CODE-SERnnn-GENnnn-####  (TYPE + GEN optional on legacy)
_ID_RE = re.compile(
    r"^(?:(?P<type>ARC|SLM)-)?"
    r"(?P<theme>[A-Z0-9]+)-(?P<code>[A-Z0-9]+)-"
    r"(?P<ser>SER\d{3})"
    r"(?:-(?P<gen>GEN\d{3}))?"
    r"-(?P<seq>\d+)$",
    re.IGNORECASE,
)

# Kin mint: KIN-{PLAYERTOKEN}-SERnnn-GENnnn-#### (TYPE is the leading KIN)
_KIN_RE = re.compile(
    r"^KIN-(?P<code>[A-Z0-9]+)-"
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
    5: "Kin",
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
    type_code: str
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

    @property
    def has_type(self) -> bool:
        return bool(self.type_code)


def roman_for(generation_number: int) -> str:
    n = int(generation_number)
    if n in _ROMAN:
        return _ROMAN[n]
    return str(n)


def series_name_for_ser_number(ser_number: int) -> str:
    return _SERIES_NAMES.get(int(ser_number), f"SER{int(ser_number):03d}")


def infer_type_code(
    *,
    theme_code: str | None = None,
    design_type: str | None = None,
    internal_id: str | None = None,
) -> str:
    """Map catalog ``type`` / theme / leading id token → ARC|SLM|KIN."""
    raw = (internal_id or "").strip().upper()
    if raw.startswith("KIN-"):
        return TYPE_KIN
    if raw.startswith("SLM-"):
        # Ambiguous until parsed — prefer design_type / theme.
        pass
    if raw.startswith("ARC-"):
        return TYPE_ARC

    dt = (design_type or "").strip().lower()
    if dt in ("slammer", "slm"):
        return TYPE_SLM
    if dt in ("kin",):
        return TYPE_KIN
    if dt in ("arcori", "arc"):
        return TYPE_ARC

    theme = (theme_code or "").strip().upper()
    if theme == TYPE_SLM:
        return TYPE_SLM
    if theme == TYPE_KIN:
        return TYPE_KIN
    return TYPE_ARC


def _series_gen_from_match(m: re.Match[str]) -> tuple[str, int, str | None, int, str]:
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
    return ser, series_number, gen_token, generation_number, m.group("seq")


def parse_design_id(internal_id: str) -> ParsedDesignId | None:
    raw = (internal_id or "").strip()
    if not raw:
        return None

    kin = _KIN_RE.match(raw)
    if kin is not None:
        ser, series_number, gen_token, generation_number, seq = _series_gen_from_match(
            kin
        )
        return ParsedDesignId(
            type_code=TYPE_KIN,
            theme_code=TYPE_KIN,
            design_code=kin.group("code").upper(),
            ser_token=ser,
            series_number=series_number,
            gen_token=gen_token,
            generation_number=generation_number,
            seq=seq,
            raw=raw,
        )

    m = _ID_RE.match(raw)
    if m is None:
        return None
    ser, series_number, gen_token, generation_number, seq = _series_gen_from_match(m)
    theme = m.group("theme").upper()
    code = m.group("code").upper()
    type_raw = m.group("type")
    if type_raw:
        type_code = type_raw.upper()
    else:
        # Legacy without TYPE: SLM-* → slammer; else ARC.
        type_code = TYPE_SLM if theme == TYPE_SLM else TYPE_ARC
    return ParsedDesignId(
        type_code=type_code,
        theme_code=theme,
        design_code=code,
        ser_token=ser,
        series_number=series_number,
        gen_token=gen_token,
        generation_number=generation_number,
        seq=seq,
        raw=raw,
    )


def format_design_id(
    *,
    type_code: str,
    theme_code: str,
    design_code: str,
    ser_token: str,
    generation_number: int,
    seq: str,
) -> str:
    gen = int(generation_number)
    t = (type_code or TYPE_ARC).strip().upper()
    if t not in KNOWN_TYPES:
        t = TYPE_ARC
    code = design_code.strip().upper()
    ser = ser_token.strip().upper()
    seq_s = seq.strip()
    # Kin keeps KIN-{token}-SERnnn-GENnnn-#### (no duplicate KIN theme segment).
    if t == TYPE_KIN:
        return f"KIN-{code}-{ser}-GEN{gen:03d}-{seq_s}"
    return (
        f"{t}-"
        f"{theme_code.strip().upper()}-"
        f"{code}-"
        f"{ser}-"
        f"GEN{gen:03d}-"
        f"{seq_s}"
    )


def with_generation(internal_id: str, generation_number: int) -> str:
    """Rewrite or insert GENnnn; always emit TYPE-THEME-CODE form."""
    parsed = parse_design_id(internal_id)
    if parsed is None:
        raise ValueError(f"Unparseable design id: {internal_id!r}")
    return format_design_id(
        type_code=parsed.type_code,
        theme_code=parsed.theme_code,
        design_code=parsed.design_code,
        ser_token=parsed.ser_token,
        generation_number=generation_number,
        seq=parsed.seq,
    )


def ensure_gen001(internal_id: str) -> str:
    """Canonical id: TYPE + GEN present (GEN001 if missing)."""
    parsed = parse_design_id(internal_id)
    if parsed is None:
        raise ValueError(f"Unparseable design id: {internal_id!r}")
    return with_generation(parsed.raw, parsed.generation_number)


def ensure_typed_id(
    internal_id: str,
    *,
    design_type: str | None = None,
    theme_code: str | None = None,
) -> str:
    """Force TYPE-THEME-CODE-SERnnn-GENnnn-####."""
    parsed = parse_design_id(internal_id)
    if parsed is None:
        raise ValueError(f"Unparseable design id: {internal_id!r}")
    type_code = parsed.type_code
    if not parsed.has_type or type_code not in KNOWN_TYPES:
        type_code = infer_type_code(
            theme_code=theme_code or parsed.theme_code,
            design_type=design_type,
            internal_id=internal_id,
        )
    # Legacy SLM-STR… parsed theme=SLM; keep theme SLM, type SLM.
    return format_design_id(
        type_code=type_code,
        theme_code=parsed.theme_code,
        design_code=parsed.design_code,
        ser_token=parsed.ser_token,
        generation_number=parsed.generation_number,
        seq=parsed.seq,
    )


def art_basename(internal_id: str) -> str:
    """Filename stem for :ro art — strip TYPE + GENnnn."""
    parsed = parse_design_id(internal_id)
    if parsed is None:
        return (internal_id or "").strip()
    return (
        f"{parsed.theme_code}-{parsed.design_code}-"
        f"{parsed.ser_token}-{parsed.seq}"
    )


def design_id_aliases(internal_id: str) -> list[str]:
    """Canonical + legacy forms (with/without TYPE, with/without GEN)."""
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
        parsed = parse_design_id(raw)
    except Exception:
        parsed = None
    if parsed is None:
        return out

    try:
        _add(art_basename(raw))
    except Exception:
        pass

    # TYPE-THEME-CODE-SER-GEN-SEQ (canonical)
    try:
        _add(ensure_typed_id(raw))
    except Exception:
        pass

    # THEME-CODE-SER-GEN-SEQ (pre-TYPE, with GEN)
    legacy_gen = (
        f"{parsed.theme_code}-{parsed.design_code}-"
        f"{parsed.ser_token}-GEN{parsed.generation_number:03d}-"
        f"{parsed.seq}"
    )
    _add(legacy_gen)

    # THEME-CODE-SER-SEQ (art / oldest)
    _add(art_basename(raw))

    # TYPE-THEME-CODE-SER-SEQ (typed, no GEN)
    _add(
        f"{parsed.type_code}-{parsed.theme_code}-{parsed.design_code}-"
        f"{parsed.ser_token}-{parsed.seq}"
    )

    return out


def generation_number_from_id(internal_id: str, default: int = 1) -> int:
    parsed = parse_design_id(internal_id)
    if parsed is None:
        return default
    return parsed.generation_number


def family_key(internal_id: str) -> str | None:
    """Stable family without GEN: TYPE-THEME-CODE-SERnnn-#### when typed."""
    parsed = parse_design_id(internal_id)
    if parsed is None:
        return None
    return (
        f"{parsed.type_code}-{parsed.theme_code}-{parsed.design_code}-"
        f"{parsed.ser_token}-{parsed.seq}"
    )


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
    # Ensure TYPE after generation rewrite.
    new_id = ensure_typed_id(
        new_id,
        design_type=str(out.get("type") or "") or None,
        theme_code=str(out.get("themeCode") or "") or None,
    )
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


def migrate_id_to_typed(internal_id: str) -> str | None:
    """Rewrite a stored id to TYPE-THEME-CODE-SER-GEN-SEQ, or None if unchanged/unparseable."""
    raw = (internal_id or "").strip()
    if not raw:
        return None
    try:
        typed = ensure_typed_id(raw)
    except ValueError:
        return None
    return typed if typed != raw else None
