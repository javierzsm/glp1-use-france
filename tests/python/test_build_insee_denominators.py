from pathlib import Path
import sys

import pytest


PYTHON_SOURCE = (
    Path(__file__).resolve().parents[2]
    / "src"
    / "python"
)
sys.path.insert(0, str(PYTHON_SOURCE))

from build_insee_denominators import (  # noqa: E402
    age_lower_bound,
    normalize_population,
    normalize_text,
    open_medic_age_code,
    population_status,
)


def test_normalize_text_repairs_spacing() -> None:
    assert normalize_text("50à 54 ans") == "50 à 54 ans"
    assert normalize_text("  0\u00a0à   4 ans ") == "0 à 4 ans"


@pytest.mark.parametrize(
    ("source", "expected"),
    [
        (
            "résultats définitifs arrêtés fin 2025",
            "definitive",
        ),
        (
            "résultats provisoires arrêtés fin 2025",
            "provisional",
        ),
        (
            "résultats précoces arrêtés fin 2025",
            "early",
        ),
        (
            "Source : Insee - Estimations de population",
            "not_specified",
        ),
    ],
)
def test_population_status(
    source: str,
    expected: str,
) -> None:
    assert population_status(source) == expected


@pytest.mark.parametrize(
    ("label", "expected"),
    [
        ("0 à 4 ans", 0),
        ("20 à 24 ans", 20),
        ("60 à 64 ans", 60),
        ("95 ans et plus", 95),
    ],
)
def test_age_lower_bound(
    label: str,
    expected: int,
) -> None:
    assert age_lower_bound(label) == expected


@pytest.mark.parametrize(
    ("lower_bound", "expected"),
    [
        (0, "0"),
        (15, "0"),
        (20, "20"),
        (55, "20"),
        (60, "60"),
        (95, "60"),
    ],
)
def test_open_medic_age_code(
    lower_bound: int,
    expected: str,
) -> None:
    assert open_medic_age_code(lower_bound) == expected


def test_normalize_population_accepts_integers() -> None:
    assert normalize_population(123, "test") == 123
    assert normalize_population(123.0, "test") == 123


@pytest.mark.parametrize(
    "value",
    [
        None,
        -1,
        12.5,
        "not numeric",
    ],
)
def test_normalize_population_rejects_invalid_values(
    value: object,
) -> None:
    with pytest.raises(ValueError):
        normalize_population(value, "test")
