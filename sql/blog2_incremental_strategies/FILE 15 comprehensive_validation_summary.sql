-- Summary statistics
SELECT 
  'Total Rows' as metric,
  COUNT(*) as value
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`

UNION ALL

SELECT 'Unique Transactions', COUNT(DISTINCT transaction_id)
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`

UNION ALL

SELECT 'Late Arrivals (Day 2)', COUNT(*)
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`
WHERE DATE(transaction_timestamp) = '2024-11-01'
  AND updated_at >= '2024-11-02 00:00:00'

UNION ALL

SELECT 'NULL updated_at', COUNTIF(updated_at IS NULL)
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`

UNION ALL

SELECT 'Timezone Issues (Day 3)', COUNT(*)
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`
WHERE DATE(transaction_timestamp) = '2024-11-02'
  AND updated_at >= '2024-11-03 00:00:00'

UNION ALL

SELECT 'Merchants with Name Changes', COUNT(*)
FROM (
  SELECT merchant_id
  FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`
  GROUP BY merchant_id
  HAVING COUNT(DISTINCT merchant_name) > 1
);

-- Expected output:
-- Total Rows: 45,000
-- Unique Transactions: 45,000
-- Late Arrivals: 150
-- NULL updated_at: 150
-- Timezone Issues: 88
-- Merchants with Name Changes: ~300

-- Date distribution breakdown
SELECT 
  'Date Distribution' as check_type,
  DATE(transaction_timestamp) as txn_date,
  COUNT(*) as row_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`
GROUP BY txn_date
ORDER BY txn_date;

-- Final validation by load day
SELECT 
  'Day 1' as day_label,
  DATE(transaction_timestamp) as txn_date,
  COUNT(*) as row_count
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`
WHERE updated_at < '2024-11-02 00:00:00'
GROUP BY txn_date

UNION ALL

SELECT 
  'Day 2' as day_label,
  DATE(transaction_timestamp) as txn_date,
  COUNT(*) as row_count
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`
WHERE updated_at >= '2024-11-02 00:00:00' 
  AND updated_at < '2024-11-03 00:00:00'
GROUP BY txn_date

UNION ALL

SELECT 
  'Day 3' as day_label,
  DATE(transaction_timestamp) as txn_date,
  COUNT(*) as row_count
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`
WHERE updated_at >= '2024-11-03 00:00:00'
GROUP BY txn_date

ORDER BY day_label, txn_date;