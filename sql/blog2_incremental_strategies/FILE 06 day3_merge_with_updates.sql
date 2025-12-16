DECLARE min_date DATE DEFAULT '2024-11-01';
DECLARE max_date DATE DEFAULT '2024-11-03';

MERGE `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions` T
USING `grand-jigsaw-476820-t1.payment_gateway_bronze.raw_transactions_day3` S
ON T.transaction_id = S.transaction_id
  AND DATE(T.transaction_timestamp) BETWEEN min_date AND max_date

WHEN MATCHED THEN
  UPDATE SET
    merchant_name = S.merchant_name,
    transaction_status = S.transaction_status,
    updated_at = S.updated_at

WHEN NOT MATCHED THEN
  INSERT (
    transaction_id, customer_id, transaction_timestamp, merchant_id, merchant_name,
    product_category, product_name, amount, fee_amount, cashback_amount,
    loyalty_points, payment_method, transaction_status, device_type,
    location_type, currency, updated_at
  ) VALUES (
    S.transaction_id, S.customer_id, S.transaction_timestamp, S.merchant_id, S.merchant_name,
    S.product_category, S.product_name, S.amount, S.fee_amount, S.cashback_amount,
    S.loyalty_points, S.payment_method, S.transaction_status, S.device_type,
    S.location_type, S.currency, S.updated_at
  );