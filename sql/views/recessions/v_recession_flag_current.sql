CREATE VIEW v_recession_flag_current AS
(
WITH usrec_table AS (
    SELECT obs_date,
           value
    FROM fact_macro_observations
    WHERE indicator_code = 'USREC'
),
with_previous AS (
    SELECT obs_date,
           value,
           LAG(value) OVER (ORDER BY obs_date) AS previous_value
    FROM usrec_table
)
SELECT
    obs_date AS transition_date,
    value AS current_status,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, obs_date)) * 12 +
    EXTRACT(MONTH FROM AGE(CURRENT_DATE, obs_date)) AS months_since_transition
FROM with_previous
WHERE value != previous_value
ORDER BY obs_date DESC
LIMIT 1
);

SELECT * FROM v_recession_flag_current;