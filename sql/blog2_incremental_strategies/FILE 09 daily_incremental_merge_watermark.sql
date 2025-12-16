DECLARE last_run_ts TIMESTAMP DEFAULT TIMESTAMP('1970-01-01 00:00:00 UTC');
DECLARE effective_ts TIMESTAMP;
DECLARE new_max_ts TIMESTAMP;
DECLARE next_watermark TIMESTAMP;

-- Load current watermark
SET last_run_ts = (
  SELECT last_run_ts
  FROM `grand-jigsaw-476820-t1.pipeline_metadata.watermarks`
  WHERE job_name = 'bronze_to_silver'
  LIMIT 1
);

IF last_run_ts IS NULL THEN
  SET last_run_ts = TIMESTAMP('1970-01-01 00:00:00 UTC');
END IF;

-- Safety gap: 2 hours
SET effective_ts = TIMESTAMP_SUB(last_run_ts, INTERVAL 2 HOUR);

-- MERGE with wildcard table pattern
MERGE INTO `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions` T
USING (
  SELECT *
  FROM `grand-jigsaw-476820-t1.payment_gateway_bronze.raw_transactions_*`
  WHERE _TABLE_SUFFIX LIKE 'day%'
    AND (updated_at > effective_ts OR updated_at IS NULL)
) S
ON T.transaction_id = S.transaction_id

-- Partition filter in WHEN MATCHED (not ON clause!)
WHEN MATCHED AND DATE(T.transaction_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY) THEN
  UPDATE SET
    customer_id = S.customer_id,
    transaction_timestamp = S.transaction_timestamp,
    merchant_id = S.merchant_id,
    merchant_name = S.merchant_name,
    product_category = S.product_category,
    product_name = S.product_name,
    amount = S.amount,
    fee_amount = S.fee_amount,
    cashback_amount = S.cashback_amount,
    loyalty_points = S.loyalty_points,
    payment_method = S.payment_method,
    transaction_status = S.transaction_status,
    device_type = S.device_type,
    location_type = S.location_type,
    currency = S.currency,
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

-- Update watermark
SET new_max_ts = (
  SELECT MAX(updated_at)
  FROM `grand-jigsaw-476820-t1.payment_gateway_bronze.raw_transactions_*`
  WHERE _TABLE_SUFFIX LIKE 'day%'
    AND (updated_at > effective_ts OR updated_at IS NULL)
);

SET next_watermark = GREATEST(last_run_ts, IFNULL(new_max_ts, last_run_ts));

UPDATE `grand-jigsaw-476820-t1.pipeline_metadata.watermarks`
SET last_run_ts = next_watermark,
    updated_at = CURRENT_TIMESTAMP(),
    needs_reprocess = 0
WHERE job_name = 'bronze_to_silver';