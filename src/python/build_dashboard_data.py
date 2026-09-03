#!/usr/bin/env python3
"""Build the small, public data bundle consumed by the static dashboard."""

from __future__ import annotations

import json
from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parents[2]
TABLES = ROOT / "output" / "tables"
OUTPUT = ROOT / "dashboard" / "data"
GEOGRAPHY = ROOT / "data" / "geography" / "france_regions_2025_100m.geojson"


def records(path: Path) -> list[dict]:
    frame = pd.read_csv(path)
    frame = frame.astype(object).where(pd.notna(frame), None)
    return frame.to_dict(orient="records")


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)

    datasets = {
        "national": "table_01_national_beneficiaries_2020_2025.csv",
        "national_change": "table_01_national_change_2020_2025.csv",
        "substances": "table_02_active_substance_annual_2019_2025.csv",
        "demographics": "table_03_demographic_rates_2020_2025.csv",
        "regional_annual": "table_05_regional_annual_2020_2025.csv",
        "regional_standardised": "table_05_regional_standardised_rates_2020_2025.csv",
        "regional_age_sex": "table_05_regional_age_sex_rates_2020_2025.csv",
        "regional_change": "table_06_regional_change_2021_2025.csv",
        "overseas_audit": "qc_07_overseas_annual_rates_2020_2025.csv",
    }

    bundle = {
        "metadata": {
            "title": "Reimbursed GLP-1 receptor agonist use in France",
            "data_through": 2025,
            "national_years": [2020, 2025],
            "additive_years": [2019, 2025],
            "standard_population_year": 2025,
            "sources": ["Open Medic", "INSEE", "Etalab / IGN ADMIN EXPRESS"],
            "analysis_version": "sap-v1.0-amendments-001-002-003",
        }
    }
    for key, filename in datasets.items():
        bundle[key] = records(TABLES / filename)

    with (OUTPUT / "dashboard.json").open("w", encoding="utf-8") as handle:
        json.dump(bundle, handle, ensure_ascii=False, allow_nan=False, separators=(",", ":"))

    with GEOGRAPHY.open(encoding="utf-8") as handle:
        geography = json.load(handle)

    metropolitan_codes = {
        "11", "24", "27", "28", "32", "44", "52", "53", "75", "76", "84", "93", "94"
    }
    features = []
    for feature in geography["features"]:
        code = str(feature["properties"]["code"])
        if code not in metropolitan_codes:
            continue
        feature["properties"]["code"] = code
        feature["properties"]["analysis_region_code"] = "93" if code == "94" else code
        features.append(feature)

    public_geography = {
        "type": "FeatureCollection",
        "features": features,
    }
    with (OUTPUT / "metropolitan_regions.geojson").open("w", encoding="utf-8") as handle:
        json.dump(public_geography, handle, ensure_ascii=False, separators=(",", ":"))

    print(f"Wrote {OUTPUT / 'dashboard.json'}")
    print(f"Wrote {OUTPUT / 'metropolitan_regions.geojson'}")


if __name__ == "__main__":
    main()
