CREATE VIEW v_latest_indicator_values AS
(
WITH sorted_by_date AS (SELECT indicator_code,
                               indicator_id,
                               obs_date,
                               value,
                               ROW_NUMBER() OVER (PARTITION BY indicator_code ORDER BY obs_date DESC) AS rn
                        FROM fact_macro_observations)
SELECT sorts.indicator_code,
       indicators.indicator_name,
       sorts.obs_date,
       sorts.value
FROM sorted_by_date sorts
         INNER JOIN dim_indicators indicators ON indicators.indicator_id = sorts.indicator_id
WHERE rn = 1
ORDER BY indicators.indicator_name
    );

SELECT *
FROM v_latest_indicator_values;