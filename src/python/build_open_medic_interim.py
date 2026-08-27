from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd

from inspect_open_medic_schema import (
    EXPECTED,
    MEASURES,
    canonicalize_columns,
    read_open_medic,
)


ROOT = Path(__file__).resolve().parents[2]

FILE_TEMPLATES = {
    ("ATC4", "national"): "atc4/NB_{year}_atc4.CSV.gz",
    ("ATC4", "age_sex"): "atc4/NB_{year}_atc4_age_sexe.CSV.gz",
    ("ATC4", "region"): "atc4/NB_{year}_atc4_reg.CSV.gz",
    (
        "ATC4",
        "age_sex_region",
    ): "atc4/NB_{year}_atc4_age_sexe_reg.CSV.gz",
    ("ATC5", "national"): "atc5/NB_{year}_atc5.CSV.gz",
}

DIMENSION_RENAMES = {
    "age": "age_code",
    "sexe": "sex_code",
    "BEN_REG": "region_code",
}

MEASURE_RENAMES = {
    "nbc": "beneficiaries",
    "REM": "reimbursed_expenditure_eur",
    "BSE": "reimbursement_base_eur",
    "BOITES": "boxes",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Build harmonised interim Open Medic datasets "
            "for selected years."
        )
    )
    parser.add_argument(
        "--years",
        nargs="+",
        type=int,
        default=[2019, 2025],
        help="Years to process; defaults to the pilot years 2019 and 2025.",
    )
    return parser.parse_args()


def relative_path(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def load_codebook() -> pd.DataFrame:
    path = ROOT / "data/metadata/atc_codes.csv"
    codebook = pd.read_csv(
        path,
        dtype=str,
        keep_default_na=False,
    )

    required = {
        "atc_level",
        "atc_code",
        "name",
        "analysis_role",
        "primary_inclusion",
    }
    missing = required.difference(codebook.columns)

    if missing:
        raise ValueError(
            f"Missing ATC codebook columns: {sorted(missing)}"
        )

    codebook["atc_level"] = (
        codebook["atc_level"].str.strip().str.upper()
    )
    codebook["atc_code"] = (
        codebook["atc_code"].str.strip().str.upper()
    )
    codebook["primary_inclusion"] = (
        codebook["primary_inclusion"].str.strip().str.upper()
    )

    primary = codebook.loc[
        codebook["primary_inclusion"].eq("TRUE")
    ].copy()

    if primary.duplicated(["atc_level", "atc_code"]).any():
        raise ValueError(
            "Duplicate primary ATC codes in the codebook."
        )

    return primary


def normalize_code_dimension(
    values: pd.Series,
    column: str,
) -> pd.Series:
    numeric = pd.to_numeric(values, errors="raise")

    if numeric.isna().any():
        raise ValueError(f"Missing values in dimension {column}")

    if not numeric.mod(1).eq(0).all():
        raise ValueError(
            f"Non-integer values in dimension {column}"
        )

    return numeric.astype("int64").astype("string")


def normalize_integer_measure(
    values: pd.Series,
    column: str,
) -> pd.Series:
    numeric = pd.to_numeric(values, errors="raise")

    if numeric.isna().any():
        raise ValueError(f"Missing values in measure {column}")

    if not numeric.mod(1).eq(0).all():
        raise ValueError(
            f"Non-integer values in measure {column}"
        )

    return numeric.astype("int64")


def transform_file(
    path: Path,
    year: int,
    atc_level: str,
    aggregation: str,
    codebook: pd.DataFrame,
) -> tuple[pd.DataFrame, dict[str, object]]:
    raw, encoding = read_open_medic(path)
    data, source_columns = canonicalize_columns(raw)

    expected_columns, source_key = EXPECTED[
        (atc_level, aggregation)
    ]

    if data.columns.tolist() != expected_columns:
        raise ValueError(
            f"Unexpected columns in {path}: "
            f"{data.columns.tolist()}"
        )

    code_column = atc_level
    label_column = f"l_{atc_level.lower()}"

    data[code_column] = (
        data[code_column]
        .astype("string")
        .str.strip()
        .str.upper()
    )

    selected_codes = codebook.loc[
        codebook["atc_level"].eq(atc_level),
        "atc_code",
    ]

    selected = data.loc[
        data[code_column].isin(selected_codes)
    ].copy()

    if selected.empty:
        raise ValueError(
            f"No primary {atc_level} codes found in {path}"
        )

    duplicate_key_rows = int(
        selected.duplicated(source_key, keep=False).sum()
    )

    if duplicate_key_rows:
        raise ValueError(
            f"Duplicate target key rows in {path}: "
            f"{duplicate_key_rows}"
        )

    selected["nbc"] = normalize_integer_measure(
        selected["nbc"],
        "nbc",
    )
    selected["BOITES"] = normalize_integer_measure(
        selected["BOITES"],
        "BOITES",
    )
    selected["REM"] = pd.to_numeric(
        selected["REM"],
        errors="raise",
    ).astype("float64")
    selected["BSE"] = pd.to_numeric(
        selected["BSE"],
        errors="raise",
    ).astype("float64")

    if selected[list(MEASURES)].isna().any().any():
        raise ValueError(f"Missing target measures in {path}")

    negative_counts = {
        measure: int(selected[measure].lt(0).sum())
        for measure in MEASURES
    }

    if negative_counts["nbc"]:
        raise ValueError(
            f"Negative beneficiary counts in {path}"
        )

    level_codebook = (
        codebook.loc[
            codebook["atc_level"].eq(atc_level)
        ]
        .set_index("atc_code")
    )

    harmonised = pd.DataFrame(index=selected.index)
    harmonised["year"] = year
    harmonised["atc_level"] = atc_level
    harmonised["aggregation"] = aggregation
    harmonised["atc_code"] = selected[code_column]
    harmonised["atc_label"] = (
        selected[label_column].astype("string").str.strip()
    )
    harmonised["atc_name"] = harmonised["atc_code"].map(
        level_codebook["name"]
    )
    harmonised["analysis_role"] = harmonised[
        "atc_code"
    ].map(level_codebook["analysis_role"])

    if harmonised[
        ["atc_name", "analysis_role"]
    ].isna().any().any():
        raise ValueError(
            f"Unmapped target ATC codes in {path}"
        )

    for source_column, output_column in (
        DIMENSION_RENAMES.items()
    ):
        if source_column in selected:
            harmonised[output_column] = (
                normalize_code_dimension(
                    selected[source_column],
                    source_column,
                )
            )
        else:
            harmonised[output_column] = pd.Series(
                pd.NA,
                index=selected.index,
                dtype="string",
            )

    for source_column, output_column in (
        MEASURE_RENAMES.items()
    ):
        harmonised[output_column] = selected[source_column]

    harmonised["source_file"] = relative_path(path)
    harmonised["source_encoding"] = encoding
    harmonised = harmonised.reset_index(drop=True)

    inventory = {
        "year": year,
        "atc_level": atc_level,
        "aggregation": aggregation,
        "source_file": relative_path(path),
        "source_encoding": encoding,
        "source_columns": "|".join(source_columns),
        "canonical_columns": "|".join(
            data.columns.astype(str)
        ),
        "input_rows": len(data),
        "target_rows": len(harmonised),
        "duplicate_target_key_rows": duplicate_key_rows,
        "negative_beneficiary_cells": negative_counts["nbc"],
        "negative_expenditure_cells": negative_counts["REM"],
        "negative_reimbursement_base_cells": negative_counts[
            "BSE"
        ],
        "negative_boxes_cells": negative_counts["BOITES"],
    }

    return harmonised, inventory


def main() -> None:
    args = parse_args()
    years = sorted(set(args.years))
    codebook = load_codebook()

    output_dir = (
        ROOT / "data/interim/open_medic/pilot"
    )
    output_dir.mkdir(parents=True, exist_ok=True)

    datasets: dict[str, list[pd.DataFrame]] = {}
    inventory_rows: list[dict[str, object]] = []

    for year in years:
        for (atc_level, aggregation), template in (
            FILE_TEMPLATES.items()
        ):
            path = (
                ROOT
                / "data/raw/open_medic"
                / str(year)
                / template.format(year=year)
            )

            if not path.is_file():
                raise FileNotFoundError(path)

            harmonised, inventory = transform_file(
                path=path,
                year=year,
                atc_level=atc_level,
                aggregation=aggregation,
                codebook=codebook,
            )

            dataset_id = (
                f"{atc_level.lower()}_{aggregation}"
            )
            datasets.setdefault(dataset_id, []).append(
                harmonised
            )
            inventory_rows.append(inventory)

    for dataset_id, frames in datasets.items():
        combined = pd.concat(
            frames,
            ignore_index=True,
        )

        sort_columns = [
            "year",
            "atc_code",
            "age_code",
            "sex_code",
            "region_code",
        ]
        combined = combined.sort_values(
            sort_columns,
            na_position="last",
        ).reset_index(drop=True)

        output_path = (
            output_dir
            / f"open_medic_{dataset_id}_pilot.parquet"
        )
        combined.to_parquet(
            output_path,
            index=False,
        )

        for row in inventory_rows:
            row_id = (
                f"{row['atc_level'].lower()}_"
                f"{row['aggregation']}"
            )
            if row_id == dataset_id:
                row["output_file"] = relative_path(
                    output_path
                )

        print(
            f"created {relative_path(output_path)} "
            f"({len(combined)} rows)"
        )

    inventory = pd.DataFrame(inventory_rows).sort_values(
        ["year", "atc_level", "aggregation"]
    )

    inventory_path = (
        ROOT
        / "data/metadata/open_medic_pilot_inventory.csv"
    )
    inventory.to_csv(
        inventory_path,
        index=False,
        lineterminator="\n",
    )

    print(
        f"Inventory: {relative_path(inventory_path)}"
    )
    print(
        f"Pilot years: {', '.join(map(str, years))}"
    )


if __name__ == "__main__":
    main()
