CREATE VIEW v_indicator_event_study AS(
WITH anchor_dates AS(
    SELECT vece.episode_number,
           fmo.indicator_id,
           MAX(fmo.obs_date) AS anchor_date
    FROM fact_macro_observations fmo
    JOIN v_economic_cycle_episodes vece
        ON fmo.obs_date <= vece.start_date
    WHERE vece.state = 1
    GROUP BY vece.episode_number, fmo.indicator_id
),
    anchor_value AS (
        SELECT anchor_dates.episode_number,
               anchor_dates.indicator_id,
               anchor_dates.anchor_date,
               fmo.value AS anchor_value
        FROM fact_macro_observations fmo
        JOIN anchor_dates
            ON anchor_dates.anchor_date = fmo.obs_date
                AND anchor_dates.indicator_id = fmo.indicator_id
    ),
    event_data AS(
SELECT vece.episode_number,
       vece.start_date AS event_date,
       fmo.indicator_id,
       fmo.obs_date,
       (EXTRACT(YEAR FROM fmo.obs_date) * 12 + EXTRACT(MONTH FROM fmo.obs_date))
-       (EXTRACT(YEAR FROM vece.start_date) * 12 + EXTRACT(MONTH FROM vece.start_date)) AS months_from_event,
       fmo.value,
       av.anchor_value AS value_at_event,
       ROUND((fmo.value / av.anchor_value * 100)::NUMERIC, 2) AS normalized_price
FROM fact_macro_observations fmo
JOIN v_economic_cycle_episodes vece
    ON fmo.obs_date BETWEEN vece.start_date - 365 AND VECE.start_date + 365
JOIN anchor_value av
    ON av.episode_number = vece.episode_number
        AND av.indicator_id = fmo.indicator_id
WHERE vece.state = 1
  AND fmo.indicator_id NOT IN (6, 7, 9, 10, 12, 15)
ORDER BY vece.episode_number, fmo.indicator_id, fmo.obs_date)
SELECT * FROM event_data
WHERE months_from_event BETWEEN -12 AND 12
ORDER BY episode_number, indicator_id, obs_date);

SELECT * FROM v_indicator_event_study;