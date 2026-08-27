from __future__ import annotations

import argparse
import csv
import hashlib
from datetime import datetime, timezone
from pathlib import Path

import requests


REFERENCE_ROLES = {"documentation", "denominator"}
MANIFEST_FIELDS = (
    "source_id",
    "provider",
    "dataset",
    "resource_role",
    "source_url",
    "source_filename",
    "local_path",
    "downloaded_at_utc",
    "file_size_bytes",
    "sha256",
    "content_type",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download prespecified documentation and denominator files."
    )
    parser.add_argument(
        "--catalog",
        type=Path,
        default=Path("data/metadata/source_catalog.csv"),
    )
    parser.add_argument(
        "--output-root",
        type=Path,
        default=Path("data/raw/reference"),
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=Path("data/metadata/reference_manifest.csv"),
    )
    return parser.parse_args()


def load_catalog(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))

    selected = [
        row for row in rows if row["resource_role"] in REFERENCE_ROLES
    ]
    if not selected:
        raise ValueError("Catalog contains no reference resources.")
    if len({row["source_id"] for row in selected}) != len(selected):
        raise ValueError("Reference source IDs must be unique.")
    if any(not row["expected_local_name"] for row in selected):
        raise ValueError("Every reference resource needs an expected local name.")
    return selected


def load_manifest(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def sha256_file(path: Path) -> tuple[int, str]:
    digest = hashlib.sha256()
    size = 0
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            size += len(block)
            digest.update(block)
    return size, digest.hexdigest()


def validate_file_signature(path: Path) -> None:
    with path.open("rb") as handle:
        signature = handle.read(8)

    suffix = path.suffix.lower()
    if suffix == ".xls" and signature != bytes.fromhex("D0CF11E0A1B11AE1"):
        raise ValueError(f"Expected an OLE Excel file: {path}")
    if suffix == ".xlsx" and not signature.startswith(b"PK\x03\x04"):
        raise ValueError(f"Expected an XLSX ZIP container: {path}")


def download_file(
    session: requests.Session,
    source_url: str,
    destination: Path,
) -> tuple[int, str, str, str]:
    if destination.exists():
        validate_file_signature(destination)
        size, sha256 = sha256_file(destination)
        return size, sha256, "existing", ""

    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_name(f"{destination.name}.part")
    try:
        with session.get(source_url, stream=True, timeout=120) as response:
            response.raise_for_status()
            content_type = response.headers.get("Content-Type", "").split(";")[0]
            digest = hashlib.sha256()
            size = 0
            with temporary.open("wb") as handle:
                for block in response.iter_content(chunk_size=1024 * 1024):
                    if not block:
                        continue
                    size += len(block)
                    digest.update(block)
                    handle.write(block)
        validate_file_signature(temporary)
        temporary.replace(destination)
    except Exception:
        temporary.unlink(missing_ok=True)
        raise

    return size, digest.hexdigest(), "downloaded", content_type


def write_manifest(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f"{path.name}.part")
    rows.sort(key=lambda row: row["source_id"])
    with temporary.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=MANIFEST_FIELDS,
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(rows)
    temporary.replace(path)


def main() -> None:
    args = parse_args()
    catalog_rows = load_catalog(args.catalog)
    existing_rows = load_manifest(args.manifest)
    by_source_id = {row["source_id"]: row for row in existing_rows}

    session = requests.Session()
    session.headers.update({"User-Agent": "Maradian-Labs-GLP1-Study/0.1"})

    for source in catalog_rows:
        source_id = source["source_id"]
        destination = args.output_root / source["expected_local_name"]
        previous = by_source_id.get(source_id, {})
        size, sha256, action, content_type = download_file(
            session,
            source["stable_url"],
            destination,
        )

        previous_sha256 = previous.get("sha256")
        if action == "existing" and previous_sha256 and previous_sha256 != sha256:
            raise RuntimeError(f"Checksum mismatch for {destination}")

        by_source_id[source_id] = {
            "source_id": source_id,
            "provider": source["provider"],
            "dataset": source["dataset"],
            "resource_role": source["resource_role"],
            "source_url": source["stable_url"],
            "source_filename": source["expected_local_name"],
            "local_path": destination.as_posix(),
            "downloaded_at_utc": previous.get("downloaded_at_utc")
            or datetime.now(timezone.utc).isoformat(),
            "file_size_bytes": str(size),
            "sha256": sha256,
            "content_type": previous.get("content_type") or content_type,
        }
        print(f"{action:10} {destination.name} ({size:,} bytes)")

    write_manifest(args.manifest, list(by_source_id.values()))
    print(f"Manifest: {args.manifest}")


if __name__ == "__main__":
    main()
