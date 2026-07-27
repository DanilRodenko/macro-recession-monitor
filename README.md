# Macro-Recession Monitor

A portfolio project for Data Analyst / BI Analyst roles, focused on banking, insurance,
fintech, and treasury use cases. The project tracks 16 U.S. macroeconomic indicators
(FRED) plus market data (S&P 500, VIX) in a PostgreSQL data warehouse, and uses that
data to answer two questions: *where is the economy right now?* and *how does that
compare to history?*

## Why this project

Most beginner data projects use synthetic or stale datasets. This one intentionally uses:
- **Real, current data** — pulled live from the FRED API and Yahoo Finance, not a static
  Kaggle snapshot.
- **Commercially relevant topic** — recession risk monitoring is directly useful to
  banking, insurance, treasury, and fintech teams making risk and planning decisions.
- **A less saturated angle** — rather than another generic "sales dashboard," this
  project applies BI tooling to macroeconomic time series and business-cycle analysis.

## Tech stack

| Layer | Tools |
|---|---|
| Data sources | FRED API (16 macro series), Yahoo Finance (`^GSPC`, `^VIX`) |
| ETL / loading | Python (pandas, SQLAlchemy, psycopg2), Jupyter |
| Database | PostgreSQL (local), pgAdmin 4 |
| Dashboard #1 | Power BI Desktop (DAX, Power Query) |
| Dashboard #2 | Tableau Desktop (JDBC → PostgreSQL) |
| IDE | PyCharm Professional |

## Database structure

Database: `recession_monitor`

- `dim_indicators` — 16 FRED macroeconomic indicators (metadata: code, name, frequency,
  units)
- `fact_macro_observations` — monthly/quarterly indicator observations (50,214 rows)
- `dim_tickers` — market tickers (`^GSPC`, `^VIX`)
- `fact_market_prices` — daily market price observations (23,467 rows)

### Indicators tracked
T10Y2Y, T10Y3M, UNRATE, ICSA, UMCSENT, CFNAI, GDPC1, CPIAUCSL, USREC, SAHMREALTIME,
HOUST, PERMIT, BAA10Y, NFCI, PAYEMS, INDPRO

### SQL views

| View | Purpose |
|---|---|
| `v_indicator_change` | Latest value per indicator + comparison vs. 1/3/12/36/60/120 months back |
| `v_recession_flag_current` | Current USREC status + months since last regime transition |
| `v_economic_cycle_episodes` | Full history of expansion/recession episodes (start, end, duration, ongoing flag), built from `USREC` using window functions (`LAG`, `SUM() OVER`) |

## Dashboard #1 — Current Status (Power BI)

Files: `dashboards/powerbi/01_current_status_dashboard.pbix`,
`dashboards/pdf/01_current_status_dashboard.pdf`

Snapshot of where each of the 16 indicators stands today, how each has changed over
multiple time horizons, and the current recession/expansion status (74 months into
the current expansion, as of the last data refresh).

## Dashboard #2 — Historical Comparison (Tableau)

Files: `dashboards/tableau/02_historical_comparison_dashboard.twbx`,
`dashboards/pdf/02_historical_comparison_dashboard.pdf`

Puts the current cycle in historical context using 70 expansion/recession episodes
spanning 1854–present:

- **Recession Timeline** — a Gantt-style view of every expansion/recession episode
  since 1854.
- **Episode Duration** — a bar chart comparing the length of every historical episode,
  with the current (ongoing) cycle highlighted separately.

**Key takeaways:**
- The current expansion cycle has lasted 74 months (since May 2020) — shorter than
  the average expansion since the 1980s (~85 months), but noticeably longer than the
  average post-war expansion since 1945 (~64 months).
- Average expansion length increased by nearly a third after the 1980s compared to
  the earlier post-war period (85 vs. 64 months) — consistent with an era of more
  active macroeconomic management (Fed policy, fiscal measures) that has meaningfully
  extended growth phases.
- A longer cycle does not by itself predict a recession — but by historical standards,
  the current cycle has not yet reached the typical length of post-1980s expansions,
  so it offers no clear signal either way.

## Data limitations (documented by design, not smoothed over)

- `T10Y2Y` (10Y–2Y Treasury spread) is only available from 1976 onward.
- `VIX` data starts in 1990; early intraday VIX data is unreliable and excluded from
  intraday-sensitive comparisons.
- `GDPC1` (real GDP) is quarterly, not monthly — `v_indicator_change` uses `CASE WHEN`
  logic so month-over-month comparisons are not computed on a quarterly series (which
  would silently repeat/misrepresent values).
- Duration in `v_economic_cycle_episodes` is measured in months (count of monthly
  USREC observations per episode), not days — matching how NBER and most economic
  literature report cycle length.

## Roadmap

- **Dashboard #3** (Tableau) — event study: indicator behavior in the months before/
  after recession onset.
- **Dashboard #4** (Power BI, bonus) — ML-based recession probability model
  (`sklearn` `LogisticRegression` using `SAHMREALTIME`).
