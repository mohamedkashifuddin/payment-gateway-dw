MERGE `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions` T
USING `grand-jigsaw-476820-t1.payment_gateway_bronze.raw_transactions_day2` S
ON T.transaction_id = S.transaction_id
WHEN NOT MATCHED AND (
  S.updated_at > (
    SELECT MAX(updated_at) 
    FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`
  )
  OR S.updated_at IS NULL
) THEN INSERT (
  transaction_id, customer_id, transaction_timestamp, merchant_id, merchant_name,
  product_category, product_name, amount, fee_amount, cashback_amount,
  loyalty_points, payment_method, transaction_status, device_type, 
  location_type, currency, updated_at
) VALUES (
  S.transaction_id, S.customer_id, S.transaction_timestamp, S.merchant_id, S.merchant_name,
  S.product_category, S.product_name, S.amount, S.fee_amount, S.cashback_amount,
  S.loyalty_points, S.payment_method, S.transaction_status, S.device_type,
  S.location_type, S.currency, S.updated_at
);

-- Validation: Total rows
SELECT COUNT(*) as total_rows 
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`;
-- Expected: 30,000

-- Validation: Day 2 specific rows
SELECT COUNT(*) as day2_rows 
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`
WHERE DATE(transaction_timestamp) = '2024-11-02'
   OR (DATE(transaction_timestamp) = '2024-11-01' AND updated_at >= '2024-11-02');
-- Expected: 15,000

-- Validation: NULL count
SELECT COUNT(*) as null_rows
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`
WHERE updated_at IS NULL;
-- Expected: 150

-- Validation: Date distribution
SELECT 
  DATE(transaction_timestamp) as txn_date,
  COUNT(*) as row_count
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`
GROUP BY txn_date
ORDER BY txn_date;
-- Expected: 
-- 2024-11-01: 15,150 (15K baseline + 150 late arrivals)
-- 2024-11-02: 14,850 (15K - 150 late arrivals)