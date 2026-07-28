CREATE VIEW v_market_event_study AS
(
WITH anchor_dates AS (SELECT vece.episode_number,
                             fmp.ticker,
                             MAX(fmp.trade_date) AS anchor_date
                      FROM fact_market_prices fmp
                               JOIN v_economic_cycle_episodes vece
                                    ON fmp.trade_date <= vece.start_date
                      WHERE vece.state = 1
                      GROUP BY vece.episode_number, fmp.ticker),
     anchor_price AS (SELECT anchor_dates.episode_number,
                             anchor_dates.ticker,
                             anchor_dates.anchor_date,
                             fmp.close AS anchor_close
                      FROM fact_market_prices fmp
                               JOIN anchor_dates
                                    ON anchor_dates.anchor_date = fmp.trade_date
                                        AND anchor_dates.ticker = fmp.ticker)
SELECT vece.episode_number,
       vece.start_date                                        AS event_date,
       fmp.ticker,
       fmp.trade_date,
       fmp.trade_date - vece.start_date                       AS days_from_event,
       fmp.close                                              AS price,
       ap.anchor_close                                        AS price_at_event,
       ROUND((fmp.close / ap.anchor_close * 100)::NUMERIC, 2) AS normalized_price
FROM fact_market_prices fmp
         JOIN v_economic_cycle_episodes vece
              ON fmp.trade_date BETWEEN vece.start_date - 365 AND vece.start_date + 365
         JOIN anchor_price ap
              ON ap.episode_number = vece.episode_number
                  AND ap.ticker = fmp.ticker
WHERE vece.state = 1
ORDER BY vece.episode_number, fmp.ticker, fmp.trade_date
    );

SELECT * FROM v_market_event_study;