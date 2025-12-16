MERGE `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions` T
USING (
  SELECT * FROM `grand-jigsaw-476820-t1.payment_gateway_bronze.raw_transactions_day1`
  UNION ALL
  SELECT * FROM `grand-jigsaw-476820-t1.payment_gateway_bronze.raw_transactions_day2`
  UNION ALL
  SELECT * FROM `grand-jigsaw-476820-t1.payment_gateway_bronze.raw_transactions_day3`
) S
ON T.transaction_id = S.transaction_id
WHEN MATCHED THEN UPDATE SET
  merchant_name = S.merchant_name,
  transaction_status = S.transaction_status,
  amount = S.amount,
  updated_at = S.updated_at
WHEN NOT MATCHED THEN
  INSERT (
    transaction_id, customer_id, transaction_timestamp, merchant_id, merchant_name,
    product_category, product_name, amount, fee_amount, cashback_amount,
    loyalty_points, payment_method, transaction_status, device_type, location_type,
    currency, updated_at
  )
  VALUES (
    S.transaction_id, S.customer_id, S.transaction_timestamp, S.merchant_id, S.merchant_name,
    S.product_category, S.product_name, S.amount, S.fee_amount, S.cashback_amount,
    S.loyalty_points, S.payment_method, S.transaction_status, S.device_type, S.location_type,
    S.currency, S.updated_at
  );

-- Validation
SELECT COUNT(*) as total_rows 
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`;
-- Expected: 45,000

SELECT DATE(transaction_timestamp) as txn_date, COUNT(*) as row_count
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`
GROUP BY txn_date ORDER BY txn_date;
-- Expected: 15,150 / 14,938 / 14,912

-- Update watermark after backfill
UPDATE `grand-jigsaw-476820-t1.pipeline_metadata.watermarks`
SET 
  last_run_ts = (
    SELECT GREATEST(
      IFNULL((SELECT MAX(updated_at) FROM `grand-jigsaw-476820-t1.payment_gateway_bronze.raw_transactions_day1`), TIMESTAMP('2015-01-01')),
      IFNULL((SELECT MAX(updated_at) FROM `grand-jigsaw-476820-t1.payment_gateway_bronze.raw_transactions_day2`), TIMESTAMP('2015-01-01')),
      IFNULL((SELECT MAX(updated_at) FROM `grand-jigsaw-476820-t1.payment_gateway_bronze.raw_transactions_day3`), TIMESTAMP('2015-01-01'))
    )
  ),
  updated_at = CURRENT_TIMESTAMP(),
  needs_reprocess = 0
WHERE job_name = 'bronze_to_silver';

-- Verify watermark
SELECT job_name, last_run_ts, updated_at
FROM `grand-jigsaw-476820-t1.pipeline_metadata.watermarks`
WHERE job_name = 'bronze_to_silver';
-- Expected: last_run_ts = 2024-11-03 23:59:57 UTC