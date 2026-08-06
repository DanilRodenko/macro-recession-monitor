# Macro-Recession Monitor

A portfolio project for Data Analyst / BI Analyst roles, focused on banking, insurance,
fintech, and treasury use cases. The project tracks 16 U.S. macroeconomic indicators
(FRED) plus market data (S&P 500, VIX) in a PostgreSQL data warehouse, and uses that
data to answer three questions: *where is the economy right now?*, *how does that
compare to history?*, and *how do markets and indicators typically behave around the
start of a recession?*

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
| Dashboard #2 & #3 | Tableau Desktop (JDBC → PostgreSQL) |
| Dashboard #4 | Power BI Desktop, scikit-learn (`LogisticRegression`), Jupyter |
| IDE | PyCharm Professional |

## Database structure

Database: `recession_monitor`

- `dim_indicators` — 16 FRED macroeconomic indicators (metadata: code, name, frequency,
  units)
- `fact_macro_observations` — monthly/quarterly indicator observations (50,214 rows)
- `dim_tickers` — market tickers (`^GSPC`, `^VIX`)
- `fact_market_prices` — daily market price observations (23,467 rows)
- `fact_recession_probability` — model-generated recession probability time series
  (monthly, 1990–present), written by the Dashboard #4 pipeline
- 
### Indicators tracked
T10Y2Y, T10Y3M, UNRATE, ICSA, UMCSENT, CFNAI, GDPC1, CPIAUCSL, USREC, SAHMREALTIME,
HOUST, PERMIT, BAA10Y, NFCI, PAYEMS, INDPRO

### SQL views

| View | Purpose |
|---|---|
| `v_indicator_change` | Latest value per indicator + comparison vs. 1/3/12/36/60/120 months back |
| `v_recession_flag_current` | Current USREC status + months since last regime transition |
| `v_economic_cycle_episodes` | Full history of expansion/recession episodes (start, end, duration, ongoing flag), built from `USREC` using window functions (`LAG`, `SUM() OVER`) |
| `v_market_event_study` | GSPC & VIX daily prices in a ±365 day window around each recession start date, normalized to 100 at t=0 (anchor = last trading date ≤ start date) |
| `v_indicator_event_study` | 10 of the 16 macro indicators in a ±12 month window around each recession start, normalized as the difference from the t=0 value (see Data limitations) |

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

## Dashboard #3 — Recession Event Study (Tableau)

Files: `dashboards/tableau/03_recession_event_study_dashboard.twbx`

Analyzes how the market and key macro indicators behave in the months before and
after the *start* of a recession (t=0), rather than just showing raw time series.
Every episode is re-anchored to its own start date so multiple historical recessions
can be compared on the same timeline.

**Panels:**
1. **S&P 500 Historical Price** — full daily price history (1970–present) with
   recession periods shaded as background bands, built from `v_economic_cycle_episodes`
   (Gantt bars overlaid on the price line via a dual-worksheet floating layout).
2. **GSPC vs VIX Combined Event Study** — dual-axis overlay of normalized S&P 500 price
   and VIX across the 7 recessions with available market data (1973–2020), each series
   normalized to 100 at t=0. Shows that market drawdowns and volatility spikes vary
   substantially in speed and depth across cycles (e.g. 2020's sharp, fast VIX spike
   vs. 2008's slower, larger, more sustained one).
3. **Macro Indicator Event Study** — a parameter-driven selector (Tableau Parameter)
   across 7 indicator groups: Yield Curve (T10Y2Y, T10Y3M), Credit Conditions (BAA10Y,
   NFCI), Labor Market (UNRATE, ICSA), Production (INDPRO), Housing (HOUST), Sentiment
   (UMCSENT), Inflation (CPIAUCSL). One indicator group is shown at a time, each with
   its own y-axis scale, to keep the very different units and magnitudes of these
   indicators readable.

**Design decisions:**
- Excluded from event study: `USREC` (already used as the source of recession dates),
  `CFNAI`, `PERMIT`, `PAYEMS` (duplicative of other tracked indicators), `GDPC1`
  (a separate regression-style question, not an event study), and `SAHMREALTIME`
  (reserved for Dashboard #4).
- A parameter/dropdown selector was used for the indicator panel instead of small
  multiples, because 7 groups × up to ~15 overlaid episodes each was too visually
  dense to read as a single grid — a single, larger, independently-scaled chart per
  group reads far better.

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
- `v_market_event_study` only covers recessions from ~1970 onward (Yahoo Finance
  history depth for `^GSPC`); `^VIX` specifically only from 1990, so only 4 of the
  7 market-event-study episodes have VIX data.
- `v_indicator_event_study` normalizes indicators as an absolute **difference** from
  the t=0 value rather than a **percentage**, because several indicators (yield curve
  spreads, `NFCI`) can be at or near zero, or negative — dividing by a near-zero
  anchor produces unstable, misleading percentage swings.

## Dashboard #4 — Recession Probability Model (Power BI)

Files: `dashboards/powerbi/04_recession_probability_dashboard.pbix`,
`notebooks/02_indicator_screening.ipynb`, `notebooks/03_feature_engineering.ipynb`,
`notebooks/04_model_training.ipynb`, `notebooks/05_export_to_postgres.ipynb`

A `scikit-learn` `LogisticRegression` model estimating the probability that a Sahm
Rule recession signal (`SAHMREALTIME`) will trigger within the next 6 months, trained
and run in Jupyter (Power BI has no Python/ML runtime), with predictions written back
to PostgreSQL for the dashboard to consume.

**Framing:** the model is best understood as a **financial vulnerability measure**,
not an event predictor. Recessions are typically triggered by exogenous shocks
(pandemics, geopolitical events, oil shocks) that no time-series model trained on
historical macro data can foresee. What the model does estimate is how fragile the
economy currently is — i.e. how likely a shock, if one occurs, is to tip conditions
into recession — based on credit stress, labor market softening, and activity
indicators. A low reading does not guarantee immunity to an external shock (COVID-19
being the clearest historical example, discussed below).

**Methodology:**
1. **Indicator screening** (`02_indicator_screening.ipynb`) — before building a
   multivariate model, all 13 eligible indicators (of 16 total; `UNRATE`,
   `SAHMREALTIME`, and `USREC` excluded — see below) were tested individually via
   univariate `LogisticRegression` with `TimeSeriesSplit` cross-validation, scored on
   PR-AUC across three candidate horizons (3/6/12 months). `BAA10Y` and `CFNAI`
   emerged as the strongest, most stable candidates.
2. **Target construction** — `SAHMREALTIME` binarized at the standard 0.5 threshold,
   then converted to a forward-looking window target: does the flag trigger at any
   point in the next *h* months. h=6 was chosen as a middle ground — h=3 behaves
   close to a nowcast with limited lead time; h=12 showed weaker signal across nearly
   all indicators in screening and dilutes the target (a wider window blurs the
   distinction between "imminent" and "still many months out").
3. **Feature engineering** — final feature set: `BAA10Y` (credit spread), `CFNAI`
   (broad economic activity), `ICSA` (initial jobless claims), `INDPRO` (industrial
   production). `PAYEMS` was tested and dropped after a VIF check showed severe
   multicollinearity with `INDPRO` (VIF > 245). A binarized yield-curve-inversion
   feature (`T10Y2Y < 0`) was also tested and ultimately dropped: despite being a
   classic recession predictor, at a fixed 6-month horizon it showed a
   counterintuitive negative coefficient — most likely because the yield curve's
   real-world lead time before a recession is long and inconsistent (roughly 6–24
   months historically), so a 6-month window often closes before the effect
   materializes.
4. **Validation** — `TimeSeriesSplit` (walk-forward, expanding window) throughout, not
   random splits. `class_weight='balanced'` used to address class imbalance (~25%
   positive months) instead of synthetic resampling (SMOTE), which doesn't respect
   temporal ordering. Evaluated on PR-AUC (not accuracy, given the imbalance), Brier
   score (probability calibration), recall, and precision.

**Result:** PR-AUC 0.76, ROC-AUC 0.78 on a chronological hold-out. All four final
coefficients have signs consistent with economic intuition (rising credit spreads and
jobless claims increase risk; stronger activity and production indices lower it).

**Dashboard:**
- Time series of the 6-month forward recession probability (1990–present), with
  historical recession periods shaded for visual reference (from
  `v_economic_cycle_episodes`, the same source used in Dashboards #2 and #3).
- Current risk reading, shown as a standalone card, with accompanying methodology and
  interpretation notes directly on the dashboard.

## Data limitations — Dashboard #4

- **No forecasting of the underlying indicators.** The model uses each indicator's
  *known* value at time *t* to estimate risk over the following 6 months — it does
  not forecast where `BAA10Y`, `CFNAI`, `ICSA`, or `INDPRO` themselves are headed.
- **Small positive-class sample.** Only ~83 of 439 months (1990–present) are
  recession months under the Sahm Rule. Some `TimeSeriesSplit` folds (e.g. the
  2013–2019 expansion) contain very few positive examples, making per-fold PR-AUC
  noisy for some indicators during screening — documented in
  `02_indicator_screening.ipynb` rather than smoothed over.
- **Yield curve inversion excluded.** See methodology above — a deliberate,
  evidence-based exclusion after testing, not an oversight.
- **Exogenous shocks are a blind spot.** COVID-19 is a clear example: it hit an
  economy that was not showing significant fragility on most of these indicators, and
  even a 6-month lookback window from several months prior does not fully capture it.
  This is a structural limitation of any model built from historical macro time series,
  not specific to this implementation.

