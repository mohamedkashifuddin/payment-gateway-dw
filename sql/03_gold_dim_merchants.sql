-- Create dim_merchants table
CREATE OR REPLACE TABLE `grand-jigsaw-476820-t1.payment_gateway_gold.dim_merchants` AS
SELECT
  -- Surrogate key
  ROW_NUMBER() OVER (ORDER BY merchant_id) AS merchant_key,
  
  -- Natural key
  merchant_id,
  
  -- Merchant attributes
  ANY_VALUE(merchant_name) AS merchant_name,  -- Pick one name (handles duplicates)
  NULL AS business_type,
  NULL AS industry,
  NULL AS country,
  NULL AS website,
  NULL AS onboarding_date,
  NULL AS settlement_frequency,
  FALSE AS is_active,
  
  -- Audit columns
  CURRENT_TIMESTAMP() AS created_at,
  CURRENT_TIMESTAMP() AS updated_at
  
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.cleaned_transactions`
GROUP BY merchant_id;  -- ← CRITICAL: Ensures one row per merchant_id

-- Validation Queries

-- Check row count
SELECT COUNT(*) as total_merchants
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.dim_merchants`;
-- Expected: 987 unique merchants

-- CRITICAL: Verify no duplicate merchant_ids
SELECT 
  merchant_id,
  COUNT(*) as count
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.dim_merchants`
GROUP BY merchant_id
HAVING COUNT(*) > 1;
-- Expected: 0 rows (this is what fixes the 29,256 row explosion bug!)

-- Check for merchants with multiple names in source (diagnostic)
SELECT 
  merchant_id,
  COUNT(DISTINCT merchant_name) as name_variations,
  STRING_AGG(DISTINCT merchant_name, ', ') as all_names
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.cleaned_transactions`
GROUP BY merchant_id
HAVING COUNT(DISTINCT merchant_name) > 1
ORDER BY name_variations DESC
LIMIT 10;
-- This shows which merchants had duplicate names (informational only)

-- Sample data
SELECT *
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.dim_merchants`
ORDER BY merchant_key
LIMIT 10;
