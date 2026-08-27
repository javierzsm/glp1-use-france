# Protocol Governance

This directory contains the prespecified scientific and analytical documentation for the study.

The protocol is intended to distinguish decisions made before analysis from decisions made after data inspection or result generation.

## Planned documents

```text
protocol/
├── README.md
├── protocol.md
├── sap.md
├── amendments.md
└── decision_log.md
```

* `protocol.md`: research question, objectives, design, population, drug definition, data sources, estimands, planned analyses and interpretation boundaries.
* `sap.md`: detailed statistical analysis plan, including derived variables, denominators, standardisation procedures, tables, figures and sensitivity analyses.
* `amendments.md`: dated changes made after protocol version 1.0 is frozen.
* `decision_log.md`: material technical or methodological decisions made while preparing the study.

## Document status

Each protocol document must state its status:

* **Draft:** under development and open to revision.
* **Frozen:** approved for analysis and assigned a version and date.
* **Amended:** changed after freezing through a documented amendment.
* **Superseded:** replaced by a later version but retained in Git history.

Protocol version 1.0 must be frozen before the primary analytical dataset is examined for study results.

## Versioning

Protocol versions will use semantic document numbering:

```text
0.1, 0.2, 0.3 — pre-analysis drafts
1.0           — first frozen protocol
1.1, 1.2      — documented amendments that do not redefine the study
2.0           — major redesign, if required
```

Git history will preserve every committed version. Previously frozen decisions must not be silently rewritten.

## Amendments

Every post-freeze amendment must record:

* amendment number;
* date;
* document and section affected;
* original specification;
* revised specification;
* reason for the change;
* whether the change was made before or after examining relevant results;
* analyses, tables or figures affected;
* person approving the amendment.

Exploratory analyses added after examining results must be labelled as exploratory and must not be presented as prespecified.

## Decision log

The decision log will capture choices that affect reproducibility or interpretation, including:

* ATC reference version;
* included and excluded substances;
* treatment of tirzepatide;
* selected Open Medic files;
* handling of unknown or suppressed categories;
* geographical harmonisation;
* population denominator vintage;
* standard population;
* treatment of corrected source releases;
* analytical dataset freeze;
* software or package changes affecting results.

Routine code refactoring that does not affect data or results does not require a methodological amendment but remains visible in Git history.

## Separation of responsibilities

The protocol defines what will be studied and why.

The statistical analysis plan defines how variables, measures and analyses will be implemented.

The code implements those specifications.

The final report describes what was done, reports deviations and interprets the results.

These layers must remain consistent, but they must not be collapsed into a single undocumented analytical script.
