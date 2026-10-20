"""Design id alias helpers (TYPE / GEN / legacy cutover)."""

from __future__ import annotations

from modules.catalog.catalog_ids import (
    art_basename,
    design_id_aliases,
    ensure_typed_id,
    parse_design_id,
    series_name_for_ser_number,
)


def test_ensure_typed_id_arcori_and_slammer() -> None:
    assert (
        ensure_typed_id("ANM-TIG-SER001-GEN001-0001")
        == "ARC-ANM-TIG-SER001-GEN001-0001"
    )
    assert (
        ensure_typed_id("SLM-STR-SER001-GEN001-0001")
        == "SLM-SLM-STR-SER001-GEN001-0001"
    )
    assert (
        ensure_typed_id("ARC-ANM-TIG-SER001-GEN001-0001")
        == "ARC-ANM-TIG-SER001-GEN001-0001"
    )


def test_kin_id_unchanged_shape() -> None:
    kin = "KIN-SIL202607092145-SER005-GEN001-0001"
    assert ensure_typed_id(kin) == kin
    parsed = parse_design_id(kin)
    assert parsed is not None
    assert parsed.type_code == "KIN"
    assert parsed.theme_code == "KIN"


def test_art_basename_strips_type_and_gen() -> None:
    assert art_basename("ARC-ANM-TIG-SER001-GEN001-0001") == "ANM-TIG-SER001-0001"
    assert art_basename("SLM-SLM-STR-SER001-GEN001-0001") == "SLM-STR-SER001-0001"


def test_design_id_aliases_include_legacy_forms() -> None:
    aliases = design_id_aliases("ARC-ANM-SNL-SER001-GEN001-0007")
    assert "ARC-ANM-SNL-SER001-GEN001-0007" in aliases
    assert "ANM-SNL-SER001-GEN001-0007" in aliases
    assert "ANM-SNL-SER001-0007" in aliases
    legacy = design_id_aliases("ANM-SNL-SER001-0007")
    assert "ARC-ANM-SNL-SER001-GEN001-0007" in legacy


def test_series_name_for_ser_number() -> None:
    assert series_name_for_ser_number(0) == "Creation"
    assert series_name_for_ser_number(3) == "Foundations"
    assert series_name_for_ser_number(4) == "Civilizations"
