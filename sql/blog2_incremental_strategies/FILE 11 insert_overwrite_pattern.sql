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
FROM `grand-jigsaw-476820-t1.payment_gateway_bronze.raw_transactions_day3`
WHERE DATE(transaction_timestamp) = '2024-11-03'
OVERWRITE PARTITIONS (DATE '2024-11-03');

-- Validation
SELECT 
  DATE(transaction_timestamp) as partition_date,
  COUNT(*) as row_count,
  MAX(updated_at) as latest_update
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`
WHERE DATE(transaction_timestamp) = '2024-11-03'
GROUP BY partition_date;
-- Expected: 2024-11-03, 15,000 rows