-- Create fact_transactions table
CREATE OR REPLACE TABLE `grand-jigsaw-476820-t1.payment_gateway_gold.fact_transactions` AS
SELECT
  -- ===================================
  -- Foreign Keys (from dimensions)
  -- ===================================
  c.customer_key,
  m.merchant_key,
  pm.payment_method_key,
  ts.status_key,
  l.location_key,
  d.date_key,
  
  -- ===================================
  -- Degenerate Dimensions
  -- ===================================
  s.transaction_id,
  s.product_category,
  s.product_name,
  s.device_type,
  
  -- ===================================
  -- Measures (Base Facts)
  -- ===================================
  s.amount,
  s.fee_amount,
  s.cashback_amount,
  s.loyalty_points,
  
  -- ===================================
  -- Derived Measures
  -- ===================================
  s.amount - s.cashback_amount AS net_customer_amount,
  s.amount - s.fee_amount AS merchant_net_amount,
  s.fee_amount - s.cashback_amount AS gateway_revenue,
  
  -- ===================================
  -- Timestamps
  -- ===================================
  s.transaction_timestamp,
  
  -- ===================================
  -- Flags & Attributes
  -- ===================================
  s.currency,
  FALSE AS is_refunded,
  NULL AS refund_amount,
  NULL AS refund_date,
  1 AS attempt_number,
  
  -- ===================================
  -- Audit Columns
  -- ===================================
  s.loaded_at,
  s.source_system,
  CURRENT_TIMESTAMP() AS created_at,
  CURRENT_TIMESTAMP() AS updated_at

FROM `grand-jigsaw-476820-t1.payment_gateway_silver.cleaned_transactions` s

-- Dimension Lookups (LEFT JOINs to preserve all fact rows)
LEFT JOIN `grand-jigsaw-476820-t1.payment_gateway_gold.dim_customers` c 
  ON s.customer_id = c.customer_id
  AND c.is_current = TRUE  -- Get current version for SCD Type 2

LEFT JOIN `grand-jigsaw-476820-t1.payment_gateway_gold.dim_merchants` m 
  ON s.merchant_id = m.merchant_id

LEFT JOIN `grand-jigsaw-476820-t1.payment_gateway_gold.dim_payment_methods` pm 
  ON s.payment_method = pm.payment_method_name

LEFT JOIN `grand-jigsaw-476820-t1.payment_gateway_gold.dim_transaction_status` ts 
  ON s.transaction_status = ts.status_name

LEFT JOIN `grand-jigsaw-476820-t1.payment_gateway_gold.dim_location` l 
  ON s.location_type = l.location_type

LEFT JOIN `grand-jigsaw-476820-t1.payment_gateway_gold.dim_date` d 
  ON CAST(FORMAT_DATE('%Y%m%d', DATE(s.transaction_timestamp)) AS INT64) = d.date_key

ORDER BY s.transaction_timestamp;

-- ===================================
-- CRITICAL VALIDATION QUERIES
-- ===================================

-- 1. Check row count (MUST match Silver!)
SELECT COUNT(*) as fact_row_count
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.fact_transactions`;
-- Expected: 5,000 rows (same as Silver)
-- If different: You have dimension duplication bug!

-- 2. Verify ALL foreign keys populated (no NULLs)
SELECT 
  COUNT(*) as total_rows,
  COUNT(customer_key) as has_customer,
  COUNT(merchant_key) as has_merchant,
  COUNT(payment_method_key) as has_payment_method,
  COUNT(status_key) as has_status,
  COUNT(location_key) as has_location,
  COUNT(date_key) as has_date
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.fact_transactions`;
-- All counts MUST equal total_rows
-- If not: Check which dimension is missing references

-- 3. Check for NULL foreign keys (diagnostic)
SELECT 
  'customer_key' as dimension,
  COUNT(*) as null_count
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.fact_transactions`
WHERE customer_key IS NULL

UNION ALL

SELECT 
  'merchant_key' as dimension,
  COUNT(*) as null_count
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.fact_transactions`
WHERE merchant_key IS NULL

UNION ALL

SELECT 
  'payment_method_key' as dimension,
  COUNT(*) as null_count
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.fact_transactions`
WHERE payment_method_key IS NULL;
-- Expected: 0 nulls for all dimensions

-- 4. Sample data check
SELECT *
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.fact_transactions`
ORDER BY transaction_timestamp
LIMIT 10;

-- 5. Check derived measures calculated correctly
SELECT 
  amount,
  cashback_amount,
  net_customer_amount,
  (amount - cashback_amount) as calculated_net,
  CASE 
    WHEN net_customer_amount = (amount - cashback_amount) THEN 'OK'
    ELSE 'ERROR'
  END as validation
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.fact_transactions`
LIMIT 10;