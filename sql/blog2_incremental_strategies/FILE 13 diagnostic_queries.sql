-- Check timezone issues
SELECT 
  COUNT(*) as suspicious_count
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`
WHERE DATE(transaction_timestamp) = '2024-11-02'
  AND DATE(updated_at) = '2024-11-03';

-- Sample suspicious rows
SELECT
  transaction_id,
  transaction_timestamp,
  updated_at,
  FORMAT_TIMESTAMP('%F %T', transaction_timestamp) AS txn_ts_string,
  FORMAT_TIMESTAMP('%F %T', updated_at) AS updated_at_string
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`
WHERE DATE(transaction_timestamp) = '2024-11-02'
  AND DATE(updated_at) = '2024-11-03'
ORDER BY updated_at
LIMIT 100;

-- Count merchant name changes in Day 3
WITH prev_name AS (
  SELECT
    merchant_id,
    ANY_VALUE(merchant_name) AS prev_name
  FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`
  WHERE DATE(transaction_timestamp) < '2024-11-03'
  GROUP BY merchant_id
)
SELECT
  COUNT(*) AS rows_with_name_change
FROM `grand-jigsaw-476820-t1.payment_gateway_bronze.raw_transactions_day3` S
LEFT JOIN prev_name P ON S.merchant_id = P.merchant_id
WHERE P.prev_name IS NOT NULL
  AND S.merchant_name != P.prev_name;

-- Count distinct merchants with name changes
WITH prev_name AS (
  SELECT merchant_id, ANY_VALUE(merchant_name) AS prev_name
  FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`
  WHERE DATE(transaction_timestamp) < '2024-11-03'
  GROUP BY merchant_id
)
SELECT
  COUNT(DISTINCT S.merchant_id) AS distinct_merchants_with_changes
FROM `grand-jigsaw-476820-t1.payment_gateway_bronze.raw_transactions_day3` S
JOIN prev_name P ON S.merchant_id = P.merchant_id
WHERE S.merchant_name != P.prev_name;

-- Show top merchants that changed
WITH prev_name AS (
  SELECT merchant_id, ANY_VALUE(merchant_name) AS prev_name
  FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`
  WHERE DATE(transaction_timestamp) < '2024-11-03'
  GROUP BY merchant_id
)
SELECT
  S.merchant_id,
  P.prev_name,
  S.merchant_name AS new_name,
  COUNT(*) AS changed_rows
FROM `grand-jigsaw-476820-t1.payment_gateway_bronze.raw_transactions_day3` S
JOIN prev_name P ON S.merchant_id = P.merchant_id
WHERE S.merchant_name != P.prev_name
GROUP BY S.merchant_id, P.prev_name, S.merchant_name
ORDER BY changed_rows DESC
LIMIT 50;