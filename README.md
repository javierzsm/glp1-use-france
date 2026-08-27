# Reimbursed Use of GLP-1 Receptor Agonists in France, 2019–2025

An open and reproducible drug-utilisation study developed by **Maradian Labs**, an independent research initiative exploring pharmacoepidemiology, real-world evidence and the secondary use of health data.

> **Project status:** Protocol development and technical setup. No analytical results are currently available.

## Overview

This project will describe how reimbursed community use of glucagon-like peptide-1 receptor agonists (GLP-1 RAs) evolved in France between 2019 and 2025.

The study will use aggregated open data produced by the French National Health Insurance and population estimates from the French National Institute of Statistics and Economic Studies. It is designed as a transparent and reproducible demonstration of drug-utilisation research using French administrative healthcare data.

The project is descriptive. It will not assess comparative effectiveness, safety, treatment adherence or causal effects.

## Research question

How did reimbursed community use of GLP-1 receptor agonists evolve in France from 2019 through 2025, nationally and according to age, sex and region of residence?

## Planned objectives

1. Describe annual numbers and population rates of beneficiaries with at least one reimbursed community dispensing of a GLP-1 RA.
2. Describe trends in reimbursed boxes, reimbursement base and reimbursed expenditure.
3. Characterise utilisation according to age, sex and region of residence.
4. Describe changes in the active-substance composition of the GLP-1 RA class.
5. Quantify regional variation using crude and age-sex-standardised rates.
6. Compare aggregate trends with previously published French studies using individual-level SNDS data.
7. Document the strengths and limitations of open aggregated healthcare data for pharmacoepidemiological research.

## Study design

The planned design is a repeated annual cross-sectional drug-utilisation study using aggregated administrative reimbursement data.

The primary study period is 2019–2025. The geographical scope is France, with regional analyses where compatible data and denominators are available.

The primary pharmacological definition will use ATC class `A10BJ`. Dual agonists classified outside this group, including tirzepatide (`A10BX16`), will not be included in the primary GLP-1 RA definition. Any broader analysis of incretin-based therapies will be prespecified and reported separately.

## Data sources

### Open Medic

The primary data source will be the complementary Open Medic databases enriched with beneficiary counts, produced by the Caisse nationale de l’Assurance Maladie.

Open Medic contains aggregated information on medicines dispensed in community pharmacies and reimbursed by French mandatory health-insurance schemes. Planned measures include beneficiary counts, reimbursed boxes, reimbursement base and reimbursed expenditure.

Official source: [Assurance Maladie — Open Medic complementary databases](https://www.assurance-maladie.ameli.fr/etudes-et-donnees/open-medic-depenses-beneficiaires-medicaments)

### Population denominators

Annual population estimates from INSEE will be used to calculate national, demographic and regional population rates.

Official source: [INSEE](https://www.insee.fr/)

## Technical approach

The project deliberately uses both Python and R, with distinct responsibilities.

| Component                                        | Primary technology |
| ------------------------------------------------ | ------------------ |
| File acquisition and download manifest           | Python             |
| Archive extraction and file verification         | Python             |
| Schema harmonisation and initial quality control | Python             |
| Shared analytical datasets                       | Parquet            |
| Epidemiological and statistical analysis         | R                  |
| Age-sex standardisation                          | R                  |
| Tables, visualisations and maps                  | R                  |
| White paper and portfolio publication            | Quarto             |
| Selected independent validation checks           | Python and R       |

Python and R will not be used to maintain two complete parallel pipelines. Selected results will be cross-checked across languages as part of quality assurance.

## Repository structure

```text
glp1-use-france/
├── README.md
├── protocol/
├── data/
│   ├── raw/
│   ├── interim/
│   ├── processed/
│   └── metadata/
├── src/
│   ├── python/
│   └── R/
├── tests/
│   ├── python/
│   └── R/
├── output/
│   ├── figures/
│   └── tables/
└── report/
```

* `protocol/`: protocol, statistical analysis plan and amendment history.
* `data/raw/`: immutable source files downloaded from official providers.
* `data/interim/`: intermediate transformed data.
* `data/processed/`: frozen analysis-ready datasets.
* `data/metadata/`: manifests, dictionaries, code lists and provenance records.
* `src/python/`: acquisition, ingestion, harmonisation and initial quality-control code.
* `src/R/`: statistical analysis, validation and visualisation code.
* `tests/`: automated and independent validation checks.
* `output/`: generated figures and tables.
* `report/`: Quarto sources for the white paper and portfolio materials.

Raw, intermediate and processed data are excluded from version control. Their provenance and reconstruction procedures will be documented.

## Reproducibility

The project will record:

* source URLs and release dates;
* download dates, file sizes and checksums;
* data dictionaries and code mappings;
* software and package versions;
* data-processing decisions;
* protocol amendments;
* quality-control results;
* commands required to reconstruct the analysis.

Python dependencies will be isolated in a project-specific virtual environment. R dependencies will be managed with `renv`. Reports will be generated programmatically with Quarto.

## Interpretation boundaries

Open Medic records reimbursed community dispensings. It does not directly measure:

* prescriptions written;
* medicines actually taken;
* treatment indication;
* treatment initiation;
* switching or persistence;
* adherence;
* clinical effectiveness;
* safety outcomes;
* non-reimbursed use.

Beneficiary counts from different active substances cannot be summed to estimate unique users of the complete class. Class-level beneficiary counts will therefore be obtained directly from ATC4 data.

Regional or demographic differences will be interpreted as descriptive aggregate variation and not as individual-level or causal effects.

## Planned outputs

* Frozen study protocol.
* Statistical analysis plan.
* ATC code list.
* Data manifest and dictionary.
* Reproducible Python and R code.
* Quality-control report.
* Scientific white paper in English.
* Executive summary in French.
* Public portfolio page with selected figures and methods.

## Project progress

* [x] Local development environment initialised.
* [x] Git version control configured.
* [x] Isolated Python environment created.
* [x] R and Python integration verified.
* [ ] Repository documentation completed.
* [ ] Reproducible dependency environments frozen.
* [ ] Protocol version 1.0 frozen.
* [ ] Data-source files selected.
* [ ] Pilot ingestion completed.
* [ ] Primary analysis completed.
* [ ] White paper released.

## Governance and licensing

Only open, aggregated and disclosure-controlled data will be used. No individual-level or personal health data will be processed.

Code, documentation and report licensing will be defined before the first public release. Third-party source data remain subject to the licences and attribution requirements of their respective producers.

## About Maradian Labs

Maradian Labs is an independent research initiative exploring pharmacoepidemiology, real-world evidence and the secondary use of health data through open and reproducible studies.

This repository is currently maintained by [Javier Zorrilla de San Martin](https://github.com/javierzsm).

