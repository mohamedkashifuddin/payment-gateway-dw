CREATE SCHEMA IF NOT EXISTS `grand-jigsaw-476820-t1.payment_gateway_bronze`;
SELECT COUNT(*) as total_rows
FROM `grand-jigsaw-476820-t1.payment_gateway_bronze.raw_transactions`;

-- Check row count
SELECT COUNT(*) as total_rows
FROM `grand-jigsaw-476820-t1.payment_gateway_bronze.raw_transactions`;
-- Expected: 5,000 rows

-- Check date range
SELECT 
  MIN(transaction_date) as earliest_transaction,
  MAX(transaction_date) as latest_transaction
FROM `grand-jigsaw-476820-t1.payment_gateway_bronze.raw_transactions`;
-- Expected: 2023-08-19 to 2024-08-18

-- Check transaction status distribution
SELECT 
  transaction_status,
  COUNT(*) as count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM `grand-jigsaw-476820-t1.payment_gateway_bronze.raw_transactions`
GROUP BY transaction_status
ORDER BY count DESC;
-- Expected: Successful (95%), Failed (3%), Pending (2%)

-- Check payment method distribution
SELECT 
  payment_method,
  COUNT(*) as count
FROM `grand-jigsaw-476820-t1.payment_gateway_bronze.raw_transactions`
GROUP BY payment_method
ORDER BY count DESC;

-- Sample data preview
SELECT *
FROM `grand-jigsaw-476820-t1.payment_gateway_bronze.raw_transactions`
LIMIT 10;