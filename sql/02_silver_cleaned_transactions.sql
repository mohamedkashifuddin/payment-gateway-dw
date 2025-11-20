-- Step 1: Create Silver Dataset
CREATE SCHEMA IF NOT EXISTS `grand-jigsaw-476820-t1.payment_gateway_silver`;

-- Step 2: Create cleaned_transactions table
CREATE OR REPLACE TABLE `grand-jigsaw-476820-t1.payment_gateway_silver.cleaned_transactions` AS
SELECT
  -- Keep original columns
  transaction_id,
  product_category,
  product_name,
  loyalty_points,
  payment_method,
  transaction_status,
  merchant_id,
  device_type,
  
  -- Renamed columns for clarity
  user_id AS customer_id,
  transaction_date AS transaction_timestamp,
  merchant_name,
  product_amount AS amount,
  transaction_fee AS fee_amount,
  cashback AS cashback_amount,
  location AS location_type,
  
  -- Added columns (missing from source)
  'INR' AS currency,
  CURRENT_TIMESTAMP() AS loaded_at,
  'kaggle_csv' AS source_system
  
FROM `grand-jigsaw-476820-t1.payment_gateway_bronze.raw_transactions`;
-- Note: We exclude 'idx' column as it's just a sequential number with no business value

-- Step 3: Validation Queries

-- Verify row count matches Bronze (no data loss)
SELECT COUNT(*) as silver_row_count
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.cleaned_transactions`;
-- Expected: 5,000 (same as Bronze)

-- Check new columns populated correctly
SELECT 
  COUNT(DISTINCT currency) as unique_currencies,
  MIN(loaded_at) as first_load_time,
  MAX(loaded_at) as last_load_time,
  COUNT(DISTINCT source_system) as unique_sources
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.cleaned_transactions`;
-- Expected: 1 currency (INR), recent timestamp, 1 source (kaggle_csv)

-- Verify renamed columns exist with correct data types
SELECT 
  customer_id,
  transaction_timestamp,
  amount,
  fee_amount,
  cashback_amount,
  location_type
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.cleaned_transactions`
LIMIT 5;

-- Check for NULL values in critical columns
SELECT 
  COUNT(*) as total_rows,
  COUNT(transaction_id) as non_null_tx_id,
  COUNT(customer_id) as non_null_customer,
  COUNT(merchant_id) as non_null_merchant,
  COUNT(amount) as non_null_amount
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.cleaned_transactions`;
-- All counts should match total_rows