# Interactive dashboard

This directory contains the static dashboard for the GLP-1 use in France study.
GitHub Pages serves the HTML, CSS, JavaScript, fonts, GeoJSON and generated JSON
bundle directly; no application server is required.

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

Plotly.js 2.35.2 is vendored in `dashboard/assets` to avoid a runtime CDN
dependency.
