-- Check MERGE job performance
SELECT
  job_id,
  total_bytes_processed / POW(10, 9) as gb_scanned,
  total_slot_ms / 1000 / 60 as slot_minutes,
  TIMESTAMP_DIFF(end_time, start_time, SECOND) as duration_seconds,
  total_bytes_billed / POW(10, 9) as gb_billed,
  ROUND(total_bytes_billed / POW(10, 12) * 5, 2) as estimated_cost_usd
FROM `region-us.INFORMATION_SCHEMA.JOBS_BY_PROJECT`
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
  AND statement_type = 'MERGE'
ORDER BY start_time DESC
LIMIT 10;

-- Check query timeline breakdown
SELECT 
  job_id, 
  stage_id, 
  name, 
  status, 
  shuffle_output_bytes / POW(10, 9) as shuffle_gb
FROM `region-us.INFORMATION_SCHEMA.JOBS_TIMELINE_BY_PROJECT`
WHERE job_id = 'your_job_id_here'  -- Replace with actual job_id
ORDER BY stage_id;

-- Monitor Bronze table statistics
SELECT 
  'Bronze Tables Processed' as metric,
  table_name,
  row_count,
  TIMESTAMP_MILLIS(creation_time) as created_at
FROM `grand-jigsaw-476820-t1.payment_gateway_bronze.__TABLES__`
WHERE table_name LIKE 'raw_transactions_%'
ORDER BY table_name;