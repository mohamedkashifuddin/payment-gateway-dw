-- Create dim_transaction_status table
CREATE OR REPLACE TABLE `grand-jigsaw-476820-t1.payment_gateway_gold.dim_transaction_status` AS
SELECT
  -- Surrogate key
  ROW_NUMBER() OVER (ORDER BY transaction_status) AS status_key,
  
  -- Status name
  transaction_status AS status_name,
  
  -- Business logic: Status category
  CASE 
    WHEN transaction_status = 'Failed' THEN 'Failed'
    WHEN transaction_status = 'Pending' THEN 'Pending'
    WHEN transaction_status = 'Successful' THEN 'Success'
  END AS status_category,
  
  -- Business logic: Is this a final state?
  CASE 
    WHEN transaction_status IN ('Failed', 'Successful') THEN TRUE
    ELSE FALSE
  END AS is_terminal,
  
  -- Business logic: Display order for UI
  CASE 
    WHEN transaction_status = 'Pending' THEN 1
    WHEN transaction_status = 'Successful' THEN 2
    WHEN transaction_status = 'Failed' THEN 3
  END AS display_order,
  
  -- Audit columns
  CURRENT_TIMESTAMP() AS created_at,
  CURRENT_TIMESTAMP() AS updated_at
  
FROM (
  SELECT DISTINCT transaction_status
  FROM `grand-jigsaw-476820-t1.payment_gateway_silver.cleaned_transactions`
)
ORDER BY status_key;

-- Validation Queries

-- Check row count
SELECT COUNT(*) as total_statuses
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.dim_transaction_status`;
-- Expected: 3 (Successful, Failed, Pending)

-- View all statuses with business logic
SELECT 
  status_key,
  status_name,
  status_category,
  is_terminal,
  display_order
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.dim_transaction_status`
ORDER BY display_order;

-- Check distribution in source data
SELECT 
  ts.status_name,
  ts.is_terminal,
  COUNT(*) as transaction_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.cleaned_transactions` s
JOIN `grand-jigsaw-476820-t1.payment_gateway_gold.dim_transaction_status` ts
  ON s.transaction_status = ts.status_name
GROUP BY ts.status_name, ts.is_terminal
ORDER BY transaction_count DESC;
