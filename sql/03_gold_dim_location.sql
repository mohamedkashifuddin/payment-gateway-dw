-- Create dim_location table
CREATE OR REPLACE TABLE `grand-jigsaw-476820-t1.payment_gateway_gold.dim_location` AS
SELECT
  -- Surrogate key
  ROW_NUMBER() OVER (ORDER BY location_type) AS location_key,
  
  -- Location type
  location_type,
  
  -- Geographic attributes (placeholders for future enrichment)
  NULL AS region,
  NULL AS state,
  NULL AS country,
  NULL AS timezone,
  
  -- Audit columns
  CURRENT_TIMESTAMP() AS created_at,
  CURRENT_TIMESTAMP() AS updated_at
  
FROM (
  SELECT DISTINCT location_type
  FROM `grand-jigsaw-476820-t1.payment_gateway_silver.cleaned_transactions`
)
ORDER BY location_key;

-- Validation Queries

-- Check row count
SELECT COUNT(*) as total_locations
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.dim_location`;
-- Expected: 3 (Urban, Suburban, Rural)

-- List all locations
SELECT 
  location_key,
  location_type
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.dim_location`
ORDER BY location_key;

-- Check distribution in source data
SELECT 
  l.location_type,
  COUNT(*) as transaction_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.cleaned_transactions` s
JOIN `grand-jigsaw-476820-t1.payment_gateway_gold.dim_location` l
  ON s.location_type = l.location_type
GROUP BY l.location_type
ORDER BY transaction_count DESC;