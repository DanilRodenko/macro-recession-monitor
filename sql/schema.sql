CREATE TABLE dim_indicators (
    indicator_code       VARCHAR(20)  PRIMARY KEY,
    indicator_name       VARCHAR(200) NOT NULL,
    source                VARCHAR(20)  NOT NULL DEFAULT 'FRED',
    frequency             VARCHAR(30)  NOT NULL,
    units                 VARCHAR(50),
    seasonal_adjustment  VARCHAR(40),
    fred_start_date       DATE,
    notes                 TEXT
);

CREATE TABLE fact_macro_observations (
    indicator_code VARCHAR(20) NOT NULL REFERENCES dim_indicators(indicator_code),
    obs_date        DATE        NOT NULL,
    value           NUMERIC(14,4),
    PRIMARY KEY (indicator_code, obs_date)
);
CREATE INDEX idx_macro_obs_date ON fact_macro_observations(obs_date);

CREATE TABLE dim_tickers (
    ticker      VARCHAR(10)  PRIMARY KEY,
    ticker_name VARCHAR(100),
    source      VARCHAR(20)  DEFAULT 'Yahoo Finance'
);

CREATE TABLE fact_market_prices (
    ticker      VARCHAR(10) NOT NULL REFERENCES dim_tickers(ticker),
    trade_date  DATE        NOT NULL,
    open        NUMERIC(12,4),
    high        NUMERIC(12,4),
    low         NUMERIC(12,4),
    close       NUMERIC(12,4),
    adj_close   NUMERIC(12,4),
    volume      BIGINT,
    PRIMARY KEY (ticker, trade_date)
);
CREATE INDEX idx_market_trade_date ON fact_market_prices(trade_date);

INSERT INTO dim_tickers (ticker, ticker_name) VALUES
('^GSPC', 'S&P 500 Index'),
('^VIX',  'CBOE Volatility Index');