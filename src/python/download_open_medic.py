from __future__ import annotations

import argparse
import csv
import hashlib
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin

import requests


MANIFEST_FIELDS = (
    "provider",
    "dataset",
    "year",
    "atc_level",
    "variant",
    "source_directory_url",
    "source_file_url",
    "source_filename",
    "local_path",
    "downloaded_at_utc",
    "file_size_bytes",
    "sha256",
)


class LinkParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self._href: str | None = None
        self.links: list[tuple[str, str]] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag.lower() != "a":
            return
        self._href = dict(attrs).get("href")

    def handle_data(self, data: str) -> None:
        if self._href and data.strip():
            self.links.append((data.strip(), self._href))

    def handle_endtag(self, tag: str) -> None:
        if tag.lower() == "a":
            self._href = None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download prespecified Open Medic complementary files."
    )
    parser.add_argument("--year", type=int, required=True, choices=range(2019, 2026))
    parser.add_argument(
        "--catalog",
        type=Path,
        default=Path("data/metadata/source_catalog.csv"),
    )
    parser.add_argument(
        "--output-root",
        type=Path,
        default=Path("data/raw/open_medic"),
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=Path("data/metadata/download_manifest.csv"),
    )
    return parser.parse_args()


def load_directory_urls(catalog: Path, year: int) -> dict[str, str]:
    with catalog.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))

    selected = {
        row["atc_level"].upper(): row["stable_url"]
        for row in rows
        if row["year"] == str(year) and row["atc_level"].upper() in {"ATC4", "ATC5"}
    }
    if set(selected) != {"ATC4", "ATC5"}:
        raise ValueError(f"Catalog must contain unique ATC4 and ATC5 rows for {year}.")
    return selected


def expected_files(year: int) -> dict[str, dict[str, str]]:
    return {
        "ATC4": {
            f"nb_{year}_atc4.csv.gz": "national",
            f"nb_{year}_atc4_age_sexe.csv.gz": "age_sex",
            f"nb_{year}_atc4_reg.csv.gz": "region",
            f"nb_{year}_atc4_age_sexe_reg.csv.gz": "age_sex_region",
        },
        "ATC5": {
            f"nb_{year}_atc5.csv.gz": "national",
        },
    }


def discover_files(session: requests.Session, directory_url: str) -> dict[str, tuple[str, str]]:
    response = session.get(directory_url, timeout=60)
    response.raise_for_status()
    parser = LinkParser()
    parser.feed(response.text)
    return {
        name.lower(): (name, urljoin(directory_url, href))
        for name, href in parser.links
        if name.lower().endswith(".csv.gz")
    }


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def download_file(
    session: requests.Session,
    url: str,
    destination: Path,
) -> tuple[int, str, str]:
    if destination.exists():
        with destination.open("rb") as handle:
            if handle.read(2) != b"\x1f\x8b":
                raise ValueError(f"Existing file is not gzip data: {destination.name}")
        return destination.stat().st_size, file_sha256(destination), "existing"

    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_name(f"{destination.name}.part")
    digest = hashlib.sha256()
    size = 0

    try:
        with session.get(url, stream=True, timeout=120) as response:
            response.raise_for_status()
            with temporary.open("wb") as handle:
                for chunk in response.iter_content(chunk_size=1024 * 1024):
                    if not chunk:
                        continue
                    handle.write(chunk)
                    digest.update(chunk)
                    size += len(chunk)

        with temporary.open("rb") as handle:
            if handle.read(2) != b"\x1f\x8b":
                raise ValueError(f"Downloaded file is not gzip data: {destination.name}")
        temporary.replace(destination)
    except Exception:
        temporary.unlink(missing_ok=True)
        raise

    return size, digest.hexdigest(), "downloaded"


def load_manifest(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def write_manifest(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f"{path.name}.part")
    rows.sort(key=lambda row: (int(row["year"]), row["atc_level"], row["variant"]))
    with temporary.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=MANIFEST_FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    temporary.replace(path)


def main() -> None:
    args = parse_args()
    directory_urls = load_directory_urls(args.catalog, args.year)
    required = expected_files(args.year)
    manifest_rows = load_manifest(args.manifest)
    by_local_path = {row["local_path"]: row for row in manifest_rows}

    session = requests.Session()
    session.headers.update({"User-Agent": "Maradian-Labs-Open-Medic-Study/0.1"})

    for level, expected in required.items():
        directory_url = directory_urls[level]
        discovered = discover_files(session, directory_url)
        missing = sorted(set(expected) - set(discovered))
        if missing:
            raise RuntimeError(f"Missing expected {level} files: {missing}")

        for normalized_name, variant in expected.items():
            source_name, source_url = discovered[normalized_name]
            destination = args.output_root / str(args.year) / level.lower() / source_name
            local_path = destination.as_posix()
            previous = by_local_path.get(local_path, {})
            size, sha256, action = download_file(session, source_url, destination)
            previous_sha256 = previous.get("sha256")
            if action == "existing" and previous_sha256 and previous_sha256 != sha256:
                raise RuntimeError(f"Checksum mismatch for existing file: {local_path}")
            downloaded_at = previous.get("downloaded_at_utc") or datetime.now(timezone.utc).isoformat()
            recorded_source_url = previous.get("source_file_url") or source_url
            by_local_path[local_path] = {
                "provider": "Assurance Maladie",
                "dataset": "Open Medic complementary databases",
                "year": str(args.year),
                "atc_level": level,
                "variant": variant,
                "source_directory_url": directory_url,
                "source_file_url": recorded_source_url,
                "source_filename": source_name,
                "local_path": local_path,
                "downloaded_at_utc": downloaded_at,
                "file_size_bytes": str(size),
                "sha256": sha256,
            }
            print(f"{action:10} {source_name} ({size:,} bytes)")

    write_manifest(args.manifest, list(by_local_path.values()))
    print(f"Manifest: {args.manifest}")


if __name__ == "__main__":
    main()
