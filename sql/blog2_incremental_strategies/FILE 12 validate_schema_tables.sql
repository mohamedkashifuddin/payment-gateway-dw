-- Check Silver table schema
SELECT column_name, data_type, is_nullable
FROM `grand-jigsaw-476820-t1.payment_gateway_silver.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'incremental_transactions'
ORDER BY ordinal_position;

-- Check Gold fact table schema
SELECT column_name, data_type, is_nullable
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'fact_transactions'
ORDER BY ordinal_position;

-- List all dimension tables
SELECT table_name, table_type, creation_time
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.INFORMATION_SCHEMA.TABLES`
WHERE table_name LIKE 'dim_%'
ORDER BY table_name;

-- Check dimension row counts
SELECT
  table_id AS table_name,
  row_count,
  TIMESTAMP_MILLIS(creation_time) AS created_at
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.__TABLES__`
WHERE table_id LIKE 'dim_%'
ORDER BY table_id;