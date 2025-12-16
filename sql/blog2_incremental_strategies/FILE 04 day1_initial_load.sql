INSERT INTO `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`
SELECT
  transaction_id,
  customer_id,
  transaction_timestamp,
  merchant_id,
  merchant_name,
  product_category,
  product_name,
  amount,
  fee_amount,
  cashback_amount,
  loyalty_points,
  payment_method,
  transaction_status,
  device_type,
  location_type,
  currency,
  updated_at
FROM `grand-jigsaw-476820-t1.payment_gateway_bronze.raw_transactions_day1`;

-- Validation queries
SELECT COUNT(*) AS silver_row_count
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`;
-- Expected: 15,000

SELECT 
  MIN(DATE(transaction_timestamp)) AS min_date,
  MAX(DATE(transaction_timestamp)) AS max_date
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`;
-- Expected: 2024-11-01, 2024-11-01

SELECT 
  COUNTIF(updated_at IS NULL) AS null_count,
  ROUND(COUNTIF(updated_at IS NULL) * 100.0 / COUNT(*), 2) AS null_pct
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`;
-- Expected: 0 NULLs (0%)
