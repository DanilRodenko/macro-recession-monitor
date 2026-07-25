CREATE VIEW v_indicator_change AS
(
WITH trunc_month AS (SELECT indicator_code,
                            indicator_id,
                            obs_date,
                            value,
                            DATE_TRUNC('month', obs_date) AS month_date
                     FROM fact_macro_observations),
     partition_month AS (SELECT indicator_code,
                                indicator_id,
                                obs_date,
                                value,
                                month_date,
                                ROW_NUMBER() OVER (PARTITION BY indicator_code, month_date ORDER BY obs_date DESC) AS mn
                         FROM trunc_month),
     compare_values AS (SELECT indicator_code,
                               indicator_id,
                               obs_date,
                               month_date,
                               mn,
                               value AS current_value,
                               CASE WHEN indicator_code = 'GDPC1' THEN NULL
                                    ELSE LAG(value, 1) OVER (PARTITION BY indicator_code ORDER BY month_date)
                               END AS previous_month_value,

                               LAG(value, CASE WHEN indicator_code = 'GDPC1' THEN 1 ELSE 3 END)
                                   OVER (PARTITION BY indicator_code ORDER BY month_date) AS previous_quarter_value,

                               LAG(value, CASE WHEN indicator_code = 'GDPC1' THEN 4 ELSE 12 END)
                                   OVER (PARTITION BY indicator_code ORDER BY month_date) AS previous_year_value,

                               LAG(value, CASE WHEN indicator_code = 'GDPC1' THEN 12 ELSE 36 END)
                                   OVER (PARTITION BY indicator_code ORDER BY month_date) AS previous_3years_value,

                               LAG(value, CASE WHEN indicator_code = 'GDPC1' THEN 20 ELSE 60 END)
                                   OVER (PARTITION BY indicator_code ORDER BY month_date) AS previous_5years_value,

                               LAG(value, CASE WHEN indicator_code = 'GDPC1' THEN 40 ELSE 120 END)
                                   OVER (PARTITION BY indicator_code ORDER BY month_date) AS previous_10years_value

                        FROM partition_month
                        WHERE mn = 1),
     last_values AS (SELECT indicator_code,
                            indicator_id,
                            obs_date,
                            month_date,
                            mn,
                            current_value,
                            previous_month_value,
                            previous_quarter_value,
                            previous_year_value,
                            previous_3years_value,
                            previous_5years_value,
                            previous_10years_value,
                            ROW_NUMBER() OVER (PARTITION BY indicator_code ORDER BY obs_date DESC) AS rn_latest
                     FROM compare_values)
SELECT last.indicator_code,
       indicators.indicator_name,
       last.obs_date,
       last.current_value,
       last.previous_month_value,
       last.previous_quarter_value,
       last.previous_year_value,
       last.previous_3years_value,
       last.previous_5years_value,
       last.previous_10years_value
FROM last_values last
         INNER JOIN dim_indicators indicators ON indicators.indicator_id = last.indicator_id
WHERE rn_latest = 1
    );

SELECT * FROM v_indicator_change;

