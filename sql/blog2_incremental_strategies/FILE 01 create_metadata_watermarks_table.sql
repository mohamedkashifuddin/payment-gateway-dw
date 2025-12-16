-- Create metadata dataset if doesn't exist
CREATE SCHEMA IF NOT EXISTS `grand-jigsaw-476820-t1.pipeline_metadata`;

-- Create watermark table (idempotent)
CREATE TABLE IF NOT EXISTS `grand-jigsaw-476820-t1.pipeline_metadata.watermarks` (
  job_name STRING NOT NULL,
  last_run_ts TIMESTAMP,
  updated_at TIMESTAMP,
  needs_reprocess INT64 DEFAULT 0,
  reprocess_from_date DATE,
  reprocess_to_date DATE
);

-- Insert initial watermark for bronze_to_silver job
INSERT INTO `grand-jigsaw-476820-t1.pipeline_metadata.watermarks`
  (job_name, last_run_ts, updated_at, needs_reprocess)
SELECT
  'bronze_to_silver',
  TIMESTAMP('2015-01-01 00:00:00 UTC'),
  CURRENT_TIMESTAMP(),
  0
WHERE NOT EXISTS (
  SELECT 1 FROM `grand-jigsaw-476820-t1.pipeline_metadata.watermarks`
  WHERE job_name = 'bronze_to_silver'
);

-- Verify watermark created
SELECT job_name, last_run_ts, updated_at
FROM `grand-jigsaw-476820-t1.pipeline_metadata.watermarks`
WHERE job_name = 'bronze_to_silver';