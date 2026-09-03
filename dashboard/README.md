# Interactive dashboard

This directory contains the static dashboard for the GLP-1 use in France study.
GitHub Pages serves the HTML, CSS, JavaScript, fonts, GeoJSON and generated JSON
bundle directly; no application server is required.

## Pages

- `index.html`: high-level overview.
- `national.html`: national levels, indexed trends and annual changes.
- `substances.html`: active-substance levels, composition and indexed trends.
- `demographics.html`: age- and sex-specific heatmaps and trajectories.
- `regions.html`: regional rankings, standardisation and longitudinal patterns.
- `maps.html`: interactive metropolitan choropleths.
- `profiles.html`: drill-down profiles for metropolitan analytical groupings.
- `overseas.html`: aggregate overseas results and denominator audit.
- `explorer.html`: filterable records and client-side CSV downloads.

## Refresh dashboard data

From the repository root:

```bash
python src/python/build_dashboard_data.py
```

This recreates `dashboard/data/dashboard.json` and
`dashboard/data/metropolitan_regions.geojson` from versioned analytical outputs.

## Preview locally

```bash
python -m http.server 8000 --directory dashboard
```

Then open `http://localhost:8000`.

## Interpretation rules

- Metropolitan maps omit individual overseas geometries.
- Corse and Provence-Alpes-Côte d'Azur share analytical grouping 93.
- Regional beneficiary counts are not additive; boxes and expenditure are.
- Disclosure-control bounds are not confidence intervals.
- Heatmaps compare one measure at a time; distinct measures do not share a
  colour scale.

Plotly.js 2.35.2 is vendored in `dashboard/assets` to avoid a runtime CDN
dependency.
