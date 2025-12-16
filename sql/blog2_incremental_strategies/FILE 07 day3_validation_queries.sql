-- Validation 1: Total rows
SELECT COUNT(*) as total_rows
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`;
-- Expected: 45,000

-- Validation 2: Date distribution
SELECT 
  DATE(transaction_timestamp) as txn_date,
  COUNT(*) as row_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`
GROUP BY txn_date
ORDER BY txn_date;
-- Expected:
-- 2024-11-01: 15,150 (33.67%)
-- 2024-11-02: 14,938 (33.20%) -- includes 88 timezone issues from Day 3
-- 2024-11-03: 14,912 (33.13%)

-- Validation 3: Merchant updates
SELECT 
  merchant_id,
  COUNT(DISTINCT merchant_name) as name_versions,
  STRING_AGG(DISTINCT merchant_name ORDER BY merchant_name) as all_names
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`
GROUP BY merchant_id
HAVING COUNT(DISTINCT merchant_name) > 1
ORDER BY name_versions DESC
LIMIT 20;
-- Expected: ~300 merchants with name changes

-- Validation 4: Check duplicates
SELECT 
  COUNT(*) as total_rows,
  COUNT(DISTINCT transaction_id) as unique_transactions,
  COUNT(*) - COUNT(DISTINCT transaction_id) as duplicates
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`;
-- Expected: duplicates = 0

-- Validation 5: Timezone issues
SELECT 
  COUNT(*) as timezone_issue_rows
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`
WHERE DATE(transaction_timestamp) = '2024-11-02'
  AND updated_at >= '2024-11-03 00:00:00';
-- Expected: 88 rows