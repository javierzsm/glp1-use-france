from pathlib import Path
import sys


PYTHON_SOURCE = (
    Path(__file__).resolve().parents[2]
    / "src"
    / "python"
)
sys.path.insert(0, str(PYTHON_SOURCE))

from build_open_medic_interim import (  # noqa: E402
    build_atc_code_mapping,
    load_codebook,
    load_historical_crosswalk,
)


def test_historical_crosswalk_maps_to_primary_codes() -> None:
    codebook = load_codebook()
    crosswalk = load_historical_crosswalk(codebook)

    assert set(crosswalk["source_year"]) == {2019}
    assert not crosswalk.duplicated(
        ["source_year", "source_atc_code"]
    ).any()

    observed_mapping = dict(
        zip(
            crosswalk["source_atc_code"],
            crosswalk["canonical_atc_code"],
            strict=True,
        )
    )
    assert observed_mapping == {
        "A10BX04": "A10BJ01",
        "A10BX07": "A10BJ02",
        "A10BX10": "A10BJ03",
        "A10BX13": "A10BJ04",
        "A10BX14": "A10BJ05",
        "A10BJ06": "A10BJ06",
    }


def test_atc_code_mapping_harmonises_2019_atc5() -> None:
    codebook = load_codebook()
    crosswalk = load_historical_crosswalk(codebook)

    mapping = build_atc_code_mapping(
        year=2019,
        atc_level="ATC5",
        codebook=codebook,
        historical_crosswalk=crosswalk,
    )

    assert mapping["A10BX04"] == "A10BJ01"
    assert mapping["A10BX07"] == "A10BJ02"
    assert mapping["A10BX10"] == "A10BJ03"
    assert mapping["A10BX13"] == "A10BJ04"
    assert mapping["A10BX14"] == "A10BJ05"
    assert mapping["A10BJ06"] == "A10BJ06"


def test_atc_code_mapping_does_not_change_atc4() -> None:
    codebook = load_codebook()
    crosswalk = load_historical_crosswalk(codebook)

    mapping = build_atc_code_mapping(
        year=2019,
        atc_level="ATC4",
        codebook=codebook,
        historical_crosswalk=crosswalk,
    )

    assert mapping == {"A10BJ": "A10BJ"}
