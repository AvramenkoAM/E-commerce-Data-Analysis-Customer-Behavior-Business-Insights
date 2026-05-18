# Dashboards

## Olist Tableau-Style Dashboard

Open `olist_tableau_style_dashboard.html` through a local static server so the page can load `bi_exports/dashboard_summary.json`.

```bash
python3 -m http.server 8765
```

Then open:

```text
http://127.0.0.1:8765/dashboards/olist_tableau_style_dashboard.html
```

The dashboard preview mirrors the referenced Tableau Public layout style while using the Olist marketplace metrics and the BI export layer from this repository.
