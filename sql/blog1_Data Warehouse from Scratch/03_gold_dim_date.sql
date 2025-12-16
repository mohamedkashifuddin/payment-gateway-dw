-- Create dim_date table
CREATE OR REPLACE TABLE `grand-jigsaw-476820-t1.payment_gateway_gold.dim_date` AS
SELECT
  -- Primary Key (YYYYMMDD format as integer)
  CAST(FORMAT_DATE('%Y%m%d', date_value) AS INT64) AS date_key,
  
  -- Full Date
  date_value AS full_date,
  
  -- Day Attributes
  EXTRACT(DAY FROM date_value) AS day_of_month,
  EXTRACT(DAYOFWEEK FROM date_value) AS day_of_week_number,  -- 1=Sunday, 7=Saturday
  FORMAT_DATE('%A', date_value) AS day_of_week_name,         -- Monday, Tuesday, etc.
  
  -- Week Attributes
  EXTRACT(WEEK FROM date_value) AS week_of_year,
  
  -- Month Attributes
  EXTRACT(MONTH FROM date_value) AS month_number,
  FORMAT_DATE('%B', date_value) AS month_name,               -- January, February, etc.
  
  -- Quarter Attributes
  EXTRACT(QUARTER FROM date_value) AS quarter,
  
  -- Year Attributes
  EXTRACT(YEAR FROM date_value) AS year,
  
  -- Business Flags
  EXTRACT(DAYOFWEEK FROM date_value) IN (1, 7) AS is_weekend,  -- Saturday/Sunday
  FALSE AS is_holiday,  -- Placeholder: Can be updated with actual holiday calendar
  
  -- Fiscal Year (Example: Apr-Mar, adjust as needed for your organization)
  CASE 
    WHEN EXTRACT(MONTH FROM date_value) >= 4 THEN EXTRACT(YEAR FROM date_value)
    ELSE EXTRACT(YEAR FROM date_value) - 1
  END AS fiscal_year,
  
  CASE 
    WHEN EXTRACT(MONTH FROM date_value) >= 4 THEN EXTRACT(QUARTER FROM date_value)
    ELSE EXTRACT(QUARTER FROM date_value) + 4
  END AS fiscal_quarter

FROM UNNEST(GENERATE_DATE_ARRAY('2015-01-01', '2030-12-31', INTERVAL 1 DAY)) AS date_value
ORDER BY date_key;

-- Validation Queries

-- Check row count
SELECT COUNT(*) as total_dates
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.dim_date`;
-- Expected: 5,844 (days from 2015-01-01 to 2030-12-31)

-- Check date range
SELECT 
  MIN(full_date) as earliest_date,
  MAX(full_date) as latest_date
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.dim_date`;
-- Expected: 2015-01-01 to 2030-12-31

-- Sample weekend dates
SELECT 
  date_key,
  full_date,
  day_of_week_name,
  is_weekend
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.dim_date`
WHERE is_weekend = TRUE
  AND year = 2023
  AND month_number = 8
ORDER BY full_date
LIMIT 10;

-- Check fiscal year logic (Aug 2023 example)
SELECT 
  full_date,
  year,
  quarter,
  fiscal_year,
  fiscal_quarter
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.dim_date`
WHERE year = 2023
  AND month_number IN (3, 4, 5)  -- Around fiscal year boundary
ORDER BY full_date;