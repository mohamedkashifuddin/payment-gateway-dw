-- Create dim_payment_methods table
CREATE OR REPLACE TABLE `grand-jigsaw-476820-t1.payment_gateway_gold.dim_payment_methods` AS
SELECT
  -- Surrogate key
  ROW_NUMBER() OVER (ORDER BY payment_method) AS payment_method_key,
  
  -- Payment method name
  payment_method AS payment_method_name,
  
  -- Attributes (placeholders)
  NULL AS method_type,
  NULL AS requires_verification,
  NULL AS average_processing_time_ms,
  NULL AS is_instant,
  
  -- Audit columns
  CURRENT_TIMESTAMP() AS created_at,
  CURRENT_TIMESTAMP() AS updated_at
  
FROM (
  SELECT DISTINCT payment_method
  FROM `grand-jigsaw-476820-t1.payment_gateway_silver.cleaned_transactions`
)
ORDER BY payment_method_key;

-- Validation Queries

-- Check row count
SELECT COUNT(*) as total_payment_methods
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.dim_payment_methods`;
-- Expected: 5 (UPI, Credit Card, Debit Card, Wallet Balance, Bank Transfer)

-- List all payment methods
SELECT 
  payment_method_key,
  payment_method_name
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.dim_payment_methods`
ORDER BY payment_method_key;

-- Check usage in source data
SELECT 
  p.payment_method_name,
  COUNT(*) as transaction_count
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.cleaned_transactions` s
JOIN `grand-jigsaw-476820-t1.payment_gateway_gold.dim_payment_methods` p
  ON s.payment_method = p.payment_method_name
GROUP BY p.payment_method_name
ORDER BY transaction_count DESC;