CREATE OR REPLACE TABLE `grand-jigsaw-476820-t1.payment_gateway_silver.incremental_transactions` (
  transaction_id STRING NOT NULL,
  customer_id STRING,
  transaction_timestamp TIMESTAMP,
  merchant_id STRING,
  merchant_name STRING,
  product_category STRING,
  product_name STRING,
  amount FLOAT64,
  fee_amount FLOAT64,
  cashback_amount FLOAT64,
  loyalty_points INT64,
  payment_method STRING,
  transaction_status STRING,
  device_type STRING,
  location_type STRING,
  currency STRING,
  updated_at TIMESTAMP
)
PARTITION BY DATE(transaction_timestamp)
CLUSTER BY merchant_id, customer_id;

-- Verify table created
SELECT table_name, ddl
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.INFORMATION_SCHEMA.TABLES`
WHERE table_name = 'incremental_transactions';