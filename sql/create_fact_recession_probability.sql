CREATE TABLE IF NOT EXISTS fact_recession_probability (
    obs_date DATE PRIMARY KEY,
    predicted_probability NUMERIC(5,4) NOT NULL
);