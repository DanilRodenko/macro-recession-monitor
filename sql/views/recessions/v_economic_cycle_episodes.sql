CREATE VIEW v_economic_cycle_episodes AS(
    WITH usrec_data AS(
    SELECT *
    FROM fact_macro_observations
    WHERE indicator_code = 'USREC'
),
    with_previous AS(
        SELECT obs_date,
               value,
               LAG(value) OVER (ORDER BY obs_date) AS previous_value
        FROM usrec_data
    ),
    tables_of_changes AS(
        SELECT
            ROW_NUMBER() OVER (ORDER BY obs_date) as episode_number,
            value as state,
            previous_value,
            obs_date as start_date,
            COALESCE(LEAD(obs_date) OVER (ORDER BY obs_date ASC), CURRENT_DATE) AS end_date,
            CASE
                WHEN LEAD(obs_date) OVER (ORDER BY obs_date ASC) IS NULL THEN TRUE ELSE FALSE
            END AS is_ongoing
        FROM with_previous
        WHERE value != previous_value OR previous_value IS NULL
    ),
    main_table AS(
        SELECT
            episode_number,
            CAST(state AS INT) AS state,
            start_date,
            end_date,
            (EXTRACT(YEAR FROM end_date) - EXTRACT(YEAR FROM start_date)) * 12 +
            (EXTRACT(MONTH FROM end_date) - EXTRACT(MONTH FROM start_date)) AS duration_months,
            is_ongoing
        FROM tables_of_changes
    )
SELECT * FROM main_table
);

SELECT * FROM v_economic_cycle_episodes;