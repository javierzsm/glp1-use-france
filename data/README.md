# Data Management

This directory contains the local data workspace and the version-controlled metadata required to reconstruct the study datasets.

The project uses only open, aggregated and disclosure-controlled data. No individual-level or personal health data may be stored in this repository.

## Directory structure

```text
data/
├── README.md
├── raw/
├── interim/
├── processed/
└── metadata/
```

## `raw/`

This directory contains files downloaded directly from official data providers.

Raw files must:

* remain unchanged after download;
* retain their original format whenever possible;
* be acquired through documented scripts rather than manual browser operations;
* be associated with a source URL, release date, download date, file size and checksum;
* never be silently overwritten by a later release.

If a provider replaces or corrects a source file, the new file must be recorded as a distinct acquisition event. Differences in checksums or metadata must be documented.

Raw data are excluded from Git version control.

## `interim/`

This directory contains temporary or intermediate datasets generated during ingestion, extraction, harmonisation and quality control.

Interim data must:

* be produced entirely from raw data and version-controlled code;
* be reproducible and disposable;
* never be edited manually;
* preserve source variables until harmonisation decisions have been documented;
* use stable and documented naming conventions.

Interim data are excluded from Git version control.

## `processed/`

This directory contains frozen analysis-ready datasets.

Processed datasets must:

* be generated programmatically;
* conform to a documented schema;
* use explicit derivation rules;
* pass predefined quality-control checks;
* be associated with a version, creation date and checksum;
* be reproducible from raw data, metadata and version-controlled code.

Processed data are excluded from Git version control. Their schemas, checksums and reconstruction instructions will remain versioned.

## `metadata/`

This directory contains version-controlled metadata and provenance records. Planned files include:

```text
data_manifest.csv
data_dictionary.csv
drug_codes.csv
region_crosswalk.csv
schema_definitions/
```

The data manifest will record, where applicable:

* data producer;
* dataset and file name;
* study year;
* ATC aggregation level;
* source URL;
* source release date;
* download timestamp;
* file size;
* cryptographic checksum;
* correction or replacement status;
* licence and attribution requirements;
* relevant processing notes.

Metadata files are part of the scientific record and must be committed to Git.

## Data-processing principles

1. Raw source files are immutable.
2. Manual spreadsheet editing is prohibited.
3. All transformations must be scripted.
4. Original and harmonised variables must remain distinguishable.
5. Exclusions and mappings must be explicit and testable.
6. Unexpected schema changes must stop the pipeline until reviewed.
7. Analysis-ready datasets must not be modified after being frozen.
8. Corrections require a new dataset version and a documented reason.

## Redistribution

Source data will not be redistributed automatically merely because they are openly accessible. Redistribution decisions will consider file size, provider licences, attribution requirements and whether direct reconstruction from the official source is preferable.

Users of this repository will be directed to the original data providers and supplied with the code and metadata required to reproduce the acquisition and processing steps.
