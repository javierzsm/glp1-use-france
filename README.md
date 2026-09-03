# Reimbursed Use of GLP-1 Receptor Agonists in France, 2019–2025

[![Dashboard](https://img.shields.io/badge/dashboard-GitHub%20Pages-147d86)](https://javierzsm.github.io/glp1-use-france/)
[![Protocol](https://img.shields.io/badge/protocol-frozen-123149)](protocol/study_protocol.qmd)
[![License: MIT](https://img.shields.io/badge/code-MIT-3487b9)](LICENSE)
[![Documentation: CC BY 4.0](https://img.shields.io/badge/documentation-CC%20BY%204.0-7c62ad)](LICENSES.md)

An open and reproducible drug-utilisation study of reimbursed glucagon-like
peptide-1 receptor agonist (GLP-1 RA) use in France. The study describes
national, active-substance, demographic and regional patterns through 2025
using aggregated administrative reimbursement data.

The project was developed by **Maradian Labs** and is maintained by
[Javier Zorrilla de San Martin](https://github.com/javierzsm).

## Explore the results

- [Interactive dashboard](https://javierzsm.github.io/glp1-use-france/)
- [Frozen study protocol](protocol/study_protocol.qmd)
- [Frozen statistical analysis plan](protocol/statistical_analysis_plan.qmd)
- [Protocol amendments](protocol/amendments/)
- [Figures](output/figures/)
- [Tables and quality-control outputs](output/tables/)
- [Figure-level reusable data](output/tables/figure_data/)
- [Release and dissemination checklist](docs/release_checklist.md)

## Research question

How did reimbursed community use of GLP-1 receptor agonists evolve in France
from 2019 through 2025, nationally and according to active substance, age, sex
and region of residence?

## Design and scope

This is a repeated annual cross-sectional drug-utilisation study. It uses
aggregated, open and disclosure-controlled data; no individual-level or
personal health data are processed.

The primary medicine definition follows WHO ATC class `A10BJ`. Tirzepatide
(`A10BX16`) is outside the primary class definition. Open Medic beneficiary
counts are non-additive across substances and regions, whereas boxes and
expenditure are additive within the documented scope.

The analyses are descriptive. They do not estimate comparative effectiveness,
safety, adherence, persistence or causal effects.

## Data sources

| Source | Contribution | Provider |
| --- | --- | --- |
| Open Medic | Beneficiaries, reimbursed boxes, reimbursement base and reimbursed expenditure | [Assurance Maladie](https://www.assurance-maladie.ameli.fr/etudes-et-donnees/open-medic-depenses-beneficiaires-medicaments) |
| Population estimates | National, demographic and regional denominators | [INSEE](https://www.insee.fr/) |
| Administrative contours | Metropolitan regional geometries | [Etalab/data.gouv.fr](https://www.data.gouv.fr/datasets/contours-administratifs), derived from IGN ADMIN EXPRESS |
| ATC classification | Operational medicine definitions | WHO Collaborating Centre for Drug Statistics Methodology |

Source URLs, acquisition dates, file sizes and checksums are recorded in
version-controlled metadata. Raw and intermediate files are reconstructed from
their official sources rather than redistributed indiscriminately.

## Main analytical domains

- National beneficiaries and population rates, 2020–2025.
- Reimbursed boxes and expenditure by active substance, 2019–2025.
- Age- and sex-specific beneficiary rates, 2020–2025.
- Crude and directly age-sex-standardised regional rates.
- Regional change and age-sex profiles.
- Aggregate audit of the combined overseas grouping.
- Metropolitan choropleth maps and common-scale temporal maps.

## Important geographic definitions

Open Medic grouping `93` combines Provence-Alpes-Côte d'Azur and Corse.
Cartographic outputs therefore show two geometries with the same analytical
estimate.

Open Medic grouping `5` combines Guadeloupe, Martinique, French Guiana, La
Réunion and Mayotte. Results cannot be attributed to any individual overseas
territory, so individual overseas geometries are deliberately omitted from the
maps. The denominator and 2023–2024 temporal pattern were independently
audited in the quality-control pipeline.

## Repository structure

```text
glp1-use-france/
├── dashboard/             # Static interactive dashboard
├── data/
│   ├── raw/               # Immutable downloads; not versioned
│   ├── interim/           # Reproducible transformations; not versioned
│   ├── processed/         # Analysis-ready data; not versioned
│   ├── geography/         # Versioned public map geometry
│   └── metadata/          # Provenance, checksums and dictionaries
├── output/
│   ├── figures/           # Publication and dissemination graphics
│   └── tables/            # Results, QC and figure data
├── protocol/              # Protocol, SAP and amendments
├── report/                # Programmatic report sources
├── src/
│   ├── python/            # Acquisition, harmonisation and independent QC
│   └── R/                 # Analysis, tables, figures and maps
├── tests/                 # Automated validation
├── renv.lock              # Frozen R dependencies
└── requirements.txt       # Frozen Python dependencies
```

## Reproducibility

### Requirements

- Python 3 with the packages pinned in `requirements.txt`;
- R with `renv`;
- Quarto for protocol and report rendering.

Create or restore the Python environment:

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
```

Restore the R environment:

```bash
Rscript -e 'renv::restore()'
```

The Python programs under `src/python/` acquire and harmonise source data,
build population denominators, perform independent audits and create the public
dashboard bundle. Use `python <script> --help` where a program accepts explicit
source or year arguments.

The principal R analysis sequence is:

```bash
Rscript src/R/01_build_analysis_datasets.R
Rscript src/R/02_national_outputs.R
Rscript src/R/03_active_substance_outputs.R
Rscript src/R/04_demographic_outputs.R
Rscript src/R/05_build_regional_datasets.R
Rscript src/R/06_regional_outputs.R
Rscript src/R/08_geospatial_outputs.R
```

Rebuild the public dashboard data after analytical outputs change:

```bash
python src/python/build_dashboard_data.py
```

Preview the dashboard locally:

```bash
python -m http.server 8000 --directory dashboard
```

Then open `http://localhost:8000`. GitHub Pages deployment is automated by
`.github/workflows/dashboard-pages.yml`.

## Governance and quality assurance

The protocol and statistical analysis plan were frozen before examination of
the primary analytical results. Post-freeze changes are retained as numbered
amendments and are not retrospectively presented as prespecified.

Quality assurance includes schema checks, source-file checksums, cross-language
validation, reconciliation of additive measures, standardisation checks,
geographic join controls and a dedicated overseas-grouping audit. Reporting
follows the RECORD-PE framework; the completed checklist accompanies the study
as supplementary information.

## Interpretation boundaries

Open Medic describes reimbursed community dispensings. It does not directly
measure prescriptions written, medicines actually taken, clinical indication,
initiation, switching, persistence, adherence, effectiveness, safety outcomes
or non-reimbursed use.

Demographic and regional findings represent aggregate variation and must not be
interpreted as individual-level associations. Disclosure-control bounds are not
sampling-based confidence intervals. Boxes are dispensing units and are not
necessarily clinically equivalent across products.

## Citation

Citation metadata are provided in [`CITATION.cff`](CITATION.cff). A versioned
DOI will be added after the first stable GitHub release is archived in Zenodo.
Until then, cite the repository with its URL and the accessed release or commit:

> Zorrilla de San Martin J. *Reimbursed Use of GLP-1 Receptor Agonists in
> France, 2019–2025*. Maradian Labs. Available from:
> https://github.com/javierzsm/glp1-use-france

## Funding and competing interests

This study was internally funded by Maradian Labs. No external commercial,
institutional or grant funding was received.

The author declares no competing interests.

## Licensing

Original source code is released under the [MIT License](LICENSE). Original
documentation, figures and tables are released under
[CC BY 4.0](LICENSES.md), unless otherwise stated. Third-party datasets and
geographic materials remain subject to the licences and attribution terms of
their respective providers.

## Project status

- [x] Protocol and statistical analysis plan frozen.
- [x] Primary and secondary analyses completed.
- [x] Quality-control and geographic audits completed.
- [x] Publication and dissemination figures generated.
- [x] Interactive dashboard published with GitHub Pages.
- [x] Manuscript draft completed and internally reviewed.
- [ ] Final manuscript package prepared for medRxiv.
- [ ] Stable repository release archived in Zenodo.
- [ ] Repository transferred to the future Maradian Labs GitHub organisation.

## About Maradian Labs

Maradian Labs is an independent research initiative specialising in
pharmacoepidemiology, real-world evidence and the secondary use of health data.
It develops transparent, reproducible studies and analytical tools for
scientific and health-system decision-making.
