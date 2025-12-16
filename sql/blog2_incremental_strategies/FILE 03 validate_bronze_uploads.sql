-- Validation 1: Check Day 1 (baseline - clean data)
SELECT 
  'Day 1' as day,
  COUNT(*) as total_rows,
  COUNT(DISTINCT transaction_id) as unique_transactions,
  COUNT(DISTINCT customer_id) as unique_customers,
  COUNT(DISTINCT merchant_id) as unique_merchants,
  MIN(transaction_timestamp) as min_date,
  MAX(transaction_timestamp) as max_date,
  COUNTIF(updated_at IS NULL) as null_updated_at
FROM `grand-jigsaw-476820-t1.payment_gateway_bronze.raw_transactions_day1`;
-- Expected: 15K rows, 0 NULLs, dates all 2024-11-01

-- Validation 2: Check Day 2 (late arrivals + NULLs)
SELECT 
  'Day 2' as day,
  COUNT(*) as total_rows,
  COUNTIF(DATE(transaction_timestamp) < '2024-11-02') as late_arriving_rows,
  COUNTIF(updated_at IS NULL) as null_updated_at
FROM `grand-jigsaw-476820-t1.payment_gateway_bronze.raw_transactions_day2`;
-- Expected: 15K rows, ~150 late arrivals, ~150 NULLs

-- Validation 3: Check Day 3 (timezone issues + merchant updates)
SELECT 
  'Day 3' as day,
  COUNT(*) as total_rows,
  COUNTIF(DATE(transaction_timestamp) < '2024-11-03') as timezone_issue_rows,
  COUNT(DISTINCT merchant_id) as unique_merchants
FROM `grand-jigsaw-476820-t1.payment_gateway_bronze.raw_transactions_day3`;
-- Expected: 15K rows, ~88 timezone issues, 500 merchants