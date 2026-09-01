# QC 07 — Overseas regional grouping audit

**Overall computational status:** PASS

## Core checks

- Direct INSEE DOM equals the sum of the five DROM in every year-age-sex cell: **True**.
- Processed annual denominators equal the direct INSEE DOM aggregate: **True**.
- Open Medic direct and age-sex-stratified numerators reconcile: **True**.
- Published crude rates reproduce from beneficiary counts and denominators: **True**.
- Published standardised rates reproduce independently: **True**.
- Local 2025 regional files match manifest checksums and were downloaded after the 10 July 2026 correction: **True**.

## Magnitude checks

- Mayotte represents 14.5% of the direct DOM population in the 2025 workbook.
- Across adult age-sex cells, the median overseas-to-metropolitan median rate ratio is 2.06.
- To reduce the 2025 crude overseas rate to the metropolitan regional median solely through the denominator would require a population 57.1% larger than the denominator used.

## Conclusion

The audit found no computational or file-version evidence that the high overseas rate is an artefact. It should nevertheless remain explicitly qualified because Open Medic exposes code 5 only as a combined grouping and because health-insurance beneficiaries and resident-population denominators are not identical populations.

## Official scope notes

- Open Medic defines `BEN_REG = 5` as *Régions et Départements d'outre-mer*.
- INSEE states that Mayotte has been included in the France field since 2014; its post-2017 population values are provisional.
- INSEE states that Guadeloupe estimates exclude Saint-Martin and Saint-Barthélemy.

Official sources:

- https://www.assurance-maladie.ameli.fr/etudes-et-donnees/open-medic-depenses-beneficiaires-medicaments
- https://www.insee.fr/fr/statistiques/8721456
