from pathlib import Path
import sys

import pandas as pd
import pytest


PYTHON_SOURCE = (
    Path(__file__).resolve().parents[2]
    / "src"
    / "python"
)
sys.path.insert(0, str(PYTHON_SOURCE))

from build_open_medic_interim import (  # noqa: E402
    load_codebook,
    normalize_code_dimension,
    normalize_integer_measure,
)


def test_normalize_code_dimension() -> None:
    values = pd.Series([0, 20, 60, 99])

    result = normalize_code_dimension(
        values,
        "age",
    )

    assert result.tolist() == ["0", "20", "60", "99"]
    assert str(result.dtype) == "string"


@pytest.mark.parametrize(
    "values",
    [
        pd.Series([0, 20.5, 60]),
        pd.Series([0, None, 60]),
    ],
)
def test_normalize_code_dimension_rejects_invalid_values(
    values: pd.Series,
) -> None:
    with pytest.raises(ValueError):
        normalize_code_dimension(values, "age")


def test_normalize_integer_measure_accepts_negative_values() -> None:
    values = pd.Series([11, 25, -3])

    result = normalize_integer_measure(
        values,
        "BOITES",
    )

    assert result.tolist() == [11, 25, -3]
    assert result.dtype == "int64"


def test_normalize_integer_measure_rejects_fractional_values() -> None:
    values = pd.Series([11, 25.5])

    with pytest.raises(ValueError):
        normalize_integer_measure(values, "nbc")


def test_load_codebook_selects_primary_definition() -> None:
    codebook = load_codebook()

    atc4_codes = set(
        codebook.loc[
            codebook["atc_level"].eq("ATC4"),
            "atc_code",
        ]
    )
    atc5_codes = set(
        codebook.loc[
            codebook["atc_level"].eq("ATC5"),
            "atc_code",
        ]
    )

    assert atc4_codes == {"A10BJ"}
    assert atc5_codes == {
        "A10BJ01",
        "A10BJ02",
        "A10BJ03",
        "A10BJ04",
        "A10BJ05",
        "A10BJ06",
        "A10BJ07",
    }

    assert "A10BX16" not in atc5_codes
    assert "A10AE54" not in atc5_codes
    assert "A10AE56" not in atc5_codes

