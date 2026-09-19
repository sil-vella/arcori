"""Design id alias helpers (GEN / non-GEN cutover)."""

from __future__ import annotations

from modules.catalog.catalog_ids import design_id_aliases, series_name_for_ser_number


def test_design_id_aliases_include_gen_and_legacy_forms() -> None:
    legacy = design_id_aliases("ANM-SNL-SER001-0007")
    with_gen = design_id_aliases("ANM-SNL-SER001-GEN001-0007")
    assert "ANM-SNL-SER001-0007" in legacy
    assert "ANM-SNL-SER001-GEN001-0007" in legacy
    assert set(legacy) == set(with_gen)


def test_series_name_for_ser_number() -> None:
    assert series_name_for_ser_number(0) == "Creation"
    assert series_name_for_ser_number(3) == "Foundations"
    assert series_name_for_ser_number(4) == "Civilizations"
