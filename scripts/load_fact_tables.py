"""
Phase 2 — Load data into recession_monitor database.

Loads:
1. dim_indicators (FRED series metadata; indicator_id is DB-generated SERIAL PK)
2. fact_macro_observations (16 FRED series, long/EAV format)
3. fact_market_prices (^GSPC, ^VIX from Yahoo Finance)
"""

import os
import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine
from fredapi import Fred
import yfinance as yf

load_dotenv()

engine = create_engine(
    f"postgresql+psycopg2://{os.getenv('DB_USER')}:{os.getenv('DB_PASSWORD')}"
    f"@{os.getenv('DB_HOST')}:{os.getenv('DB_PORT')}/recession_monitor"
)

fred = Fred(api_key=os.getenv('FRED_API_KEY'))

series_ids = [
    'T10Y2Y', 'T10Y3M', 'UNRATE', 'ICSA', 'UMCSENT', 'CFNAI',
    'GDPC1', 'CPIAUCSL', 'USREC', 'SAHMREALTIME', 'HOUST', 'PERMIT',
    'BAA10Y', 'NFCI', 'PAYEMS', 'INDPRO'
]

# ---------------------------------------------------------------------------
# 1. Build dim_indicators_df and load into dim_indicators
# ---------------------------------------------------------------------------

indicator_records = []
for series_id in series_ids:
    info = fred.get_series_info(series_id)
    indicator_records.append({
        'indicator_code': info['id'],
        'indicator_name': info['title'],
        'source': 'FRED',
        'frequency': info['frequency'],
        'units': info['units'],
        'seasonal_adjustment': info['seasonal_adjustment'],
        'fred_start_date': info['observation_start'],
        'notes': info.get('notes', None)
    })

dim_indicators_df = pd.DataFrame(indicator_records)

# indicator_id is SERIAL in Postgres — do NOT set it manually, the DB assigns it
dim_indicators_df.to_sql(
    'dim_indicators',
    engine,
    if_exists='append',
    index=False,
    method='multi'
)

print(f"Loaded {len(dim_indicators_df)} rows into dim_indicators")

# read back DB-assigned indicator_id to build the FK map for fact table loading
dim_indicators_lookup = pd.read_sql(
    'SELECT indicator_id, indicator_code FROM dim_indicators', engine
)
indicator_id_map = dict(zip(dim_indicators_lookup['indicator_code'], dim_indicators_lookup['indicator_id']))

# ---------------------------------------------------------------------------
# 2. Load fact_macro_observations (16 FRED series)
# ---------------------------------------------------------------------------

failed_series = []

for series_id in series_ids:
    try:
        data = fred.get_series(series_id)

        df = data.reset_index()
        df.columns = ['obs_date', 'value']  # matches actual DB column name
        df['indicator_id'] = indicator_id_map[series_id]
        df['indicator_code'] = series_id  # denormalized field kept in fact table for readability

        df = df.dropna(subset=['value'])

        df.to_sql(
            'fact_macro_observations',
            engine,
            if_exists='append',
            index=False,
            method='multi'
        )

        print(f"{series_id} (indicator_id={indicator_id_map[series_id]}): loaded {len(df)} rows")

    except KeyError:
        print(f"ERROR: {series_id} not found in indicator_id_map — check dim_indicators_df")
        failed_series.append(series_id)
    except Exception as e:
        print(f"ERROR loading {series_id}: {e}")
        failed_series.append(series_id)

if failed_series:
    print(f"\nFailed series: {failed_series}")

# ---------------------------------------------------------------------------
# 3. Load fact_market_prices (^GSPC, ^VIX)
# ---------------------------------------------------------------------------

gspc = yf.download('^GSPC', start='1970-01-02', auto_adjust=False)
gspc.columns = gspc.columns.droplevel(1)  # fix MultiIndex columns

vix = yf.download('^VIX', start='1990-01-02', auto_adjust=False)
vix.columns = vix.columns.droplevel(1)  # fix MultiIndex columns

column_rename_map = {
    'Date': 'trade_date',
    'Open': 'open',
    'High': 'high',
    'Low': 'low',
    'Close': 'close',
    'Adj Close': 'adj_close',
    'Volume': 'volume'
}

market_frames = []

for df_raw, ticker in [(gspc, '^GSPC'), (vix, '^VIX')]:
    df = df_raw.reset_index()
    df = df.rename(columns=column_rename_map)
    df['ticker'] = ticker  # dim_tickers PK is a text ticker, no surrogate key needed
    market_frames.append(df)

market_df = pd.concat(market_frames, ignore_index=True)

market_df.to_sql(
    'fact_market_prices',
    engine,
    if_exists='append',
    index=False,
    method='multi'
)

print(f"Loaded {len(market_df)} rows into fact_market_prices")