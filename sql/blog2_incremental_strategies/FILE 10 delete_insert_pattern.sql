DECLARE expected_delete_count INT64 DEFAULT 15000;
DECLARE actual_delete_count INT64;

-- Safety check before DELETE
SET actual_delete_count = (
  SELECT COUNT(*) 
  FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`
  WHERE DATE(transaction_timestamp) = '2024-11-02'
     OR (DATE(transaction_timestamp) = '2024-11-01' 
         AND updated_at >= '2024-11-02')
);

ASSERT actual_delete_count <= expected_delete_count * 1.1
  AS 'Delete count exceeds expected by 10%! Stopping for safety.';

-- DELETE old Day 2 data
DELETE FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`
WHERE DATE(transaction_timestamp) = '2024-11-02'
   OR (DATE(transaction_timestamp) = '2024-11-01' 
       AND updated_at >= '2024-11-02');

-- Verify delete
SELECT 'After DELETE' as checkpoint, COUNT(*) as remaining_rows
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`;
-- Expected: 30,000 rows

-- INSERT corrected data
INSERT INTO `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`
SELECT * 
FROM `grand-jigsaw-476820-t1.payment_gateway_bronze.raw_transactions_day2`;

-- Final verification
SELECT 'After INSERT' as checkpoint, COUNT(*) as total_rows
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions`;
-- Expected: 45,000 rows