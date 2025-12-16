-- Create Gold Dataset (if not exists)
CREATE SCHEMA IF NOT EXISTS `grand-jigsaw-476820-t1.payment_gateway_gold`;

-- Create dim_customers table
CREATE OR REPLACE TABLE `grand-jigsaw-476820-t1.payment_gateway_gold.dim_customers` AS
SELECT
  -- Surrogate key (auto-generated)
  ROW_NUMBER() OVER (ORDER BY customer_id) AS customer_key,
  
  -- Natural key
  customer_id,
  
  -- Customer attributes (placeholders for future enrichment)
  NULL AS customer_name,
  NULL AS email,
  NULL AS phone,
  NULL AS country,
  NULL AS city,
  NULL AS customer_segment,
  NULL AS registration_date,
  NULL AS is_verified,
  NULL AS risk_score,
  
  -- SCD Type 2 columns
  CURRENT_TIMESTAMP() AS effective_start_date,
  NULL AS effective_end_date,
  TRUE AS is_current,
  
  -- Audit columns
  CURRENT_TIMESTAMP() AS created_at,
  CURRENT_TIMESTAMP() AS updated_at
  
FROM (
  SELECT DISTINCT customer_id
  FROM `grand-jigsaw-476820-t1.payment_gateway_silver.cleaned_transactions`
)
ORDER BY customer_key;

-- Validation Queries

-- Check row count (unique customers)
SELECT COUNT(*) as total_customers
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.dim_customers`;
-- Expected: ~1,000 unique customers

-- Verify no duplicate customer_ids (for current records)
SELECT 
  customer_id,
  COUNT(*) as count
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.dim_customers`
WHERE is_current = TRUE
GROUP BY customer_id
HAVING COUNT(*) > 1;
-- Expected: 0 rows (no duplicates)

-- Check surrogate key range
SELECT 
  MIN(customer_key) as min_key,
  MAX(customer_key) as max_key,
  COUNT(DISTINCT customer_key) as unique_keys
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.dim_customers`;

-- Sample data
SELECT *
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.dim_customers`
ORDER BY customer_key
LIMIT 10;
