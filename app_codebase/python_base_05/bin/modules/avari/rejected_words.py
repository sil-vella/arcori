"""Player display-name moderation — rejected swear/blasphemy tokens.

Used for Kin chosen names, account usernames, and Avari display names.
Languages: English, Spanish, French, German, Portuguese.
List is high-signal and intentionally not exhaustive; extend in-file as needed.
"""

from __future__ import annotations

import re
import unicodedata

# Normalized lowercase tokens / multi-word phrases (spaces allowed).
# Curated common swear and blasphemy terms — not exhaustive.
_RAW_REJECTED: tuple[str, ...] = (
    # English
    "fuck",
    "fucker",
    "fucking",
    "shit",
    "asshole",
    "bastard",
    "bitch",
    "cunt",
    "dick",
    "piss",
    "whore",
    "slut",
    "nigger",
    "nigga",
    "faggot",
    "retard",
    "motherfucker",
    "goddamn",
    "god damn",
    "jesus fucking christ",
    "damn god",
    # Spanish
    "puta",
    "puto",
    "mierda",
    "cabron",
    "cabrón",
    "coño",
    "cono",
    "joder",
    "gilipollas",
    "pendejo",
    "pendeja",
    "hijueputa",
    "hijo de puta",
    "la puta",
    "carajo",
    "cojones",
    "maricon",
    "maricón",
    "hostia",
    "me cago en dios",
    "cago en dios",
    # French
    "putain",
    "merde",
    "connard",
    "connasse",
    "salope",
    "encule",
    "enculé",
    "bordel",
    "foutre",
    "bite",
    "couilles",
    "nique",
    "niquer",
    "ta mere",
    "ta mère",
    "fils de pute",
    "nom de dieu",
    "bordel de dieu",
    # German
    "scheisse",
    "scheiße",
    "scheisse",
    "arschloch",
    "fotze",
    "hurensohn",
    "wichser",
    "schwuchtel",
    "fick",
    "ficken",
    "verfickt",
    "miststück",
    "miststuck",
    "gottverdammt",
    "herrgott",
    "jesus christus",
    # Portuguese
    "porra",
    "caralho",
    "merda",
    "puta",
    "puto",
    "foda",
    "foder",
    "fodase",
    "foda se",
    "foda-se",
    "cuzao",
    "cuzão",
    "buceta",
    "viado",
    "filho da puta",
    "vai se foder",
    "desgraca",
    "desgraça",
    "puxa vida deus",
    "meu deus do ceu",
)


def _normalize_token(raw: str) -> str:
    """NFKD lowercase, strip marks, keep letters and spaces only."""
    text = unicodedata.normalize("NFKD", (raw or "").strip().lower())
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    text = re.sub(r"[^a-z\s]+", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def normalize_name_for_moderation(name: str) -> str:
    """Normalize a display name for rejected-word matching (spaced tokens)."""
    return _normalize_token(name)


def _compact_letters(name: str) -> str:
    """Letters-only form so ``Sh!t`` / ``f.u.c.k`` still match."""
    text = unicodedata.normalize("NFKD", (name or "").strip().lower())
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    # Light leetspeak → letters before stripping punctuation.
    text = text.translate(
        str.maketrans(
            {
                "!": "i",
                "1": "i",
                "@": "a",
                "0": "o",
                "3": "e",
                "4": "a",
                "5": "s",
                "$": "s",
                "7": "t",
            }
        )
    )
    return re.sub(r"[^a-z]+", "", text)


def _build_rejected_set() -> frozenset[str]:
    out: set[str] = set()
    for raw in _RAW_REJECTED:
        norm = _normalize_token(raw)
        if norm:
            out.add(norm)
    return frozenset(out)


REJECTED_WORDS: frozenset[str] = _build_rejected_set()

# Pre-split phrases (2+ tokens) for contiguous sequence checks.
_REJECTED_PHRASES: tuple[tuple[str, ...], ...] = tuple(
    sorted(
        (tuple(w.split()) for w in REJECTED_WORDS if " " in w),
        key=len,
        reverse=True,
    )
)
_REJECTED_SINGLE: frozenset[str] = frozenset(w for w in REJECTED_WORDS if " " not in w)

REJECTED_NAME_USER_MESSAGE = "That name isn’t allowed. Please choose another."
REJECTED_KIN_NAME_USER_MESSAGE = (
    "That Kin name isn’t allowed. Please choose another."
)


def is_rejected_player_name(name: str) -> bool:
    """True if the name contains a rejected whole token or banned phrase.

    Also rejects when a banned single word of length >= 4 appears inside a
    token or the letters-only compaction (e.g. ``shitlord``, ``Sh!t``), while
    short stems like ``ass`` do not block ``assassin``.
    """
    normalized = normalize_name_for_moderation(name)
    compact = _compact_letters(name)
    if not normalized and not compact:
        return False
    tokens = normalized.split() if normalized else []
    token_set = set(tokens)
    if token_set & _REJECTED_SINGLE:
        return True
    for banned in _REJECTED_SINGLE:
        if len(banned) < 4:
            continue
        if any(banned in token for token in tokens):
            return True
        if banned in compact:
            return True
    for phrase in _REJECTED_PHRASES:
        n = len(phrase)
        if n <= len(tokens):
            for i in range(len(tokens) - n + 1):
                if tuple(tokens[i : i + n]) == phrase:
                    return True
        joined = "".join(phrase)
        if len(joined) >= 4 and joined in compact:
            return True
    return False


# Back-compat alias for Kin claim.
is_rejected_kin_name = is_rejected_player_name
