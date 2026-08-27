from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

import pandas as pd


EXPECTED = {
    ("ATC4", "national"): (["ATC4", "l_atc4", "nbc", "REM", "BSE", "BOITES"], ["ATC4"]),
    ("ATC4", "age_sex"): (
        ["ATC4", "l_atc4", "age", "sexe", "nbc", "REM", "BSE", "BOITES"],
        ["ATC4", "age", "sexe"],
    ),
    ("ATC4", "region"): (
        ["ATC4", "l_atc4", "BEN_REG", "nbc", "REM", "BSE", "BOITES"],
        ["ATC4", "BEN_REG"],
    ),
    ("ATC4", "age_sex_region"): (
        ["ATC4", "l_atc4", "age", "sexe", "BEN_REG", "nbc", "REM", "BSE", "BOITES"],
        ["ATC4", "age", "sexe", "BEN_REG"],
    ),
    ("ATC5", "national"): (["ATC5", "l_atc5", "nbc", "REM", "BSE", "BOITES"], ["ATC5"]),
}

MEASURES = ("nbc", "REM", "BSE", "BOITES")
DIMENSIONS = ("age", "sexe", "BEN_REG")
ENCODINGS = ("utf-8", "cp1252", "latin-1")

CANONICAL_COLUMNS = {
    "atc4": "ATC4",
    "l_atc4": "l_atc4",
    "atc5": "ATC5",
    "l_atc5": "l_atc5",
    "age": "age",
    "sexe": "sexe",
    "ben_reg": "BEN_REG",
    "nbc": "nbc",
    "rem": "REM",
    "bse": "BSE",
    "boites": "BOITES",
}

def canonicalize_columns(
    data: pd.DataFrame,
) -> tuple[pd.DataFrame, list[str]]:
    source_columns = data.columns.tolist()
    unknown_columns = [
        column
        for column in source_columns
        if column.lower() not in CANONICAL_COLUMNS
    ]

    if unknown_columns:
        raise ValueError(
            f"Unknown source columns: {unknown_columns}"
        )

    canonical_columns = [
        CANONICAL_COLUMNS[column.lower()]
        for column in source_columns
    ]

    if len(canonical_columns) != len(set(canonical_columns)):
        raise ValueError(
            f"Duplicate columns after normalization: {canonical_columns}"
        )

    normalized = data.copy()
    normalized.columns = canonical_columns

    return normalized, source_columns

def read_open_medic(path: Path) -> tuple[pd.DataFrame, str]:
    last_error: UnicodeDecodeError | None = None

    for encoding in ENCODINGS:
        try:
            data = pd.read_csv(
                path,
                sep=";",
                compression="gzip",
                encoding=encoding,
                decimal=",",
                thousands=".",
            )
            return data, encoding
        except UnicodeDecodeError as error:
            last_error = error

    raise RuntimeError(f"Unable to decode {path}") from last_error

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Inspect Open Medic file structure without producing study results."
    )
    parser.add_argument("--year", type=int, required=True, choices=range(2019, 2026))
    parser.add_argument(
        "--manifest",
        type=Path,
        default=Path("data/metadata/download_manifest.csv"),
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("data/metadata"),
    )
    return parser.parse_args()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def join_values(values: pd.Series) -> str:
    unique = sorted(values.dropna().unique().tolist())
    return "|".join(str(value) for value in unique)


def main() -> None:
    args = parse_args()
    manifest = pd.read_csv(args.manifest, dtype=str)
    selected = manifest.loc[manifest["year"] == str(args.year)].copy()

    if selected.empty:
        raise ValueError(f"Manifest contains no files for {args.year}.")
    if selected["local_path"].duplicated().any():
        raise ValueError("Manifest contains duplicate local paths.")

    file_rows: list[dict[str, object]] = []
    column_rows: list[dict[str, object]] = []
    category_rows: list[dict[str, object]] = []

    for record in selected.sort_values(["atc_level", "variant"]).to_dict("records"):
        level = record["atc_level"]
        variant = record["variant"]
        specification = EXPECTED.get((level, variant))
        if specification is None:
            raise ValueError(f"Unexpected file specification: {level}/{variant}")
        expected_columns, key_columns = specification

        path = Path(record["local_path"])
        if not path.is_file():
            raise FileNotFoundError(path)

        actual_size = path.stat().st_size
        actual_sha256 = sha256_file(path)
        if actual_size != int(record["file_size_bytes"]):
            raise ValueError(f"File-size mismatch: {path}")
        if actual_sha256 != record["sha256"]:
            raise ValueError(f"Checksum mismatch: {path}")

        data, encoding = read_open_medic(path)
        data, source_columns = canonicalize_columns(data)

        columns_match = data.columns.tolist() == expected_columns
        if not columns_match:
            raise ValueError(
                f"Unexpected columns in {path}: {data.columns.tolist()}"
            )

        duplicate_keys = int(data.duplicated(subset=key_columns).sum())
        negative_counts = {
            column: int((data[column].dropna() < 0).sum())
            for column in MEASURES
        }
        negative_cells = sum(negative_counts.values())

        file_rows.append(
            {
                "year": args.year,
                "atc_level": level,
                "variant": variant,
                "source_filename": record["source_filename"],
                "local_path": path.as_posix(),
                "file_size_bytes": actual_size,
                "sha256": actual_sha256,
                "source_columns": "|".join(source_columns),
                "canonical_columns": "|".join(data.columns),
                "encoding": encoding,
                "delimiter": ";",
                "decimal_mark": ",",
                "thousands_mark": ".",
                "row_count": len(data),
                "column_count": len(data.columns),
                "columns_match_expected": columns_match,
                "key_columns": "|".join(key_columns),
                "duplicate_key_rows": duplicate_keys,
                "negative_nbc_cells": negative_counts["nbc"],
                "negative_rem_cells": negative_counts["REM"],
                "negative_bse_cells": negative_counts["BSE"],
                "negative_boxes_cells": negative_counts["BOITES"],
                "negative_measure_cells": negative_cells,
            }
        )

        for position, (source_column, column) in enumerate(
            zip(source_columns, data.columns),
            start=1,
        ):
            column_rows.append(
                {
                    "year": args.year,
                    "atc_level": level,
                    "variant": variant,
                    "source_filename": record["source_filename"],
                    "position": position,
                    "source_column": source_column,
                    "column": column,
                    "pandas_dtype": str(data[column].dtype),
                    "missing_count": int(data[column].isna().sum()),
                    "distinct_count": int(
                        data[column].nunique(dropna=True)
                    ),
                }
            )

        for dimension in DIMENSIONS:
            if dimension in data.columns:
                category_rows.append(
                    {
                        "year": args.year,
                        "atc_level": level,
                        "variant": variant,
                        "source_filename": record["source_filename"],
                        "dimension": dimension,
                        "values": join_values(data[dimension]),
                    }
                )

        print(
            f"checked {record['source_filename']}: "
            f"{len(data):,} rows, {duplicate_keys} duplicate keys"
        )

    args.output_dir.mkdir(parents=True, exist_ok=True)
    outputs = {
        args.output_dir / f"open_medic_file_inventory_{args.year}.csv": file_rows,
        args.output_dir / f"open_medic_column_inventory_{args.year}.csv": column_rows,
        args.output_dir / f"open_medic_category_inventory_{args.year}.csv": category_rows,
    }
    for path, rows in outputs.items():
        pd.DataFrame(rows).to_csv(path, index=False, lineterminator="\n")
        print(f"written {path}")


if __name__ == "__main__":
    main()
