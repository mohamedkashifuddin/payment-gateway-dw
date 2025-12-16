# Blog 2B: Production Implementation Guide

**Production Incremental Loads: Bronze→Silver→Gold Pipeline**

> 📖 **Read the full blog post:** [Blog 2B on Medium](#)

This document provides a reference guide for implementing the complete production pipeline covered in Blog 2B. For the full tutorial with explanations, read the blog post.

---

## 🎯 What Blog 2B Covers

Blog 2B focuses on **production implementation**. It builds a complete Bronze→Silver→Gold pipeline with watermark tracking, dimension loads, fact loads, and Cloud Workflows automation.

### Learning Objectives

After reading Blog 2B, you should be able to:

1. **Implement watermark-driven loads** across all three layers
2. **Load dimensions incrementally** using SCD Type 1
3. **Load fact tables** with proper dimension lookups
4. **Build end-to-end pipelines** that run daily
5. **Deploy Cloud Workflows** for automation
6. **Monitor and validate** production data quality

### Primary Code Focus

- **Folders:**
  - `sql/blog2_incremental_strategies/03_silver_to_gold/` (6 files)
  - `sql/blog2_incremental_strategies/04_end_to_end/` (3 files)
  - `workflows/` (2 YAML + README)
  
- **Dataset:** Complete Day 1-3 pipeline execution

---

## 🗂️ Pipeline Architecture

### Three-Layer Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│                    BRONZE LAYER (Raw)                        │
│  raw_transactions_day1, day2, day3                          │
│  - No transformations                                        │
│  - Immutable source of truth                                │
└─────────────────────────────────────────────────────────────┘
                          ↓
                   WATERMARK 1:
                 bronze_to_silver
                          ↓
┌─────────────────────────────────────────────────────────────┐
│                 SILVER LAYER (Cleaned)                       │
│  incremental_transactions                                    │
│  - MERGE with 7-day lookback                                │
│  - Handles late arrivals, NULLs, updates                    │
└─────────────────────────────────────────────────────────────┘
                          ↓
            ┌─────────────┴─────────────┐
            ↓                           ↓
     WATERMARK 2:                WATERMARK 3:
  silver_to_gold_dims        silver_to_gold_fact
            ↓                           ↓
┌──────────────────────┐     ┌────────────────────────┐
│  GOLD LAYER (Dims)   │     │  GOLD LAYER (Facts)    │
│  dim_merchants       │     │  fact_transactions     │
│  - SCD Type 1        │     │  - Dimension lookups   │
│  - Staging pattern   │     │  - Unknown keys (-1)   │
└──────────────────────┘     └────────────────────────┘
```

### Watermark Strategy

**Why separate watermarks?**

Each layer processes data independently:

- **bronze_to_silver**: Tracks when Bronze was last processed
- **silver_to_gold_dims**: Tracks when dimensions were last updated
- **silver_to_gold_fact**: Tracks when facts were last loaded

This allows:
- ✅ Independent layer reprocessing
- ✅ Parallel dimension and fact loads
- ✅ Clear failure isolation
- ✅ Easy debugging

---

## 🚀 Implementation Steps

### Step 1: Bronze → Silver (Watermark-Driven MERGE)

**Goal:** Load new/changed transactions from Bronze to Silver with automatic late arrival handling.

**Script:** `FILE 09 daily_incremental_merge_watermark.sql`

**Key features:**
- Watermark with 2-hour safety gap
- 7-day lookback window
- Wildcard table pattern (`raw_transactions_*`)
- NULL timestamp handling
- Partition pruning optimization

**Pattern:**
```sql
DECLARE last_run_ts TIMESTAMP;
DECLARE effective_ts TIMESTAMP;

-- Load watermark
SET last_run_ts = (
  SELECT last_run_ts 
  FROM watermarks 
  WHERE job_name = 'bronze_to_silver'
);

-- Add 2-hour safety gap
SET effective_ts = TIMESTAMP_SUB(last_run_ts, INTERVAL 2 HOUR);

-- MERGE with wildcard pattern
MERGE silver.incremental_transactions T
USING (
  SELECT * FROM bronze.raw_transactions_*
  WHERE _TABLE_SUFFIX LIKE 'day%'
    AND (updated_at > effective_ts OR updated_at IS NULL)
) S
ON T.transaction_id = S.transaction_id

WHEN MATCHED AND DATE(T.transaction_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY) THEN
  UPDATE SET ...
WHEN NOT MATCHED THEN
  INSERT ...;

-- Update watermark
UPDATE watermarks
SET last_run_ts = (SELECT MAX(updated_at) FROM source)
WHERE job_name = 'bronze_to_silver';
```

**Validation:**
```sql
-- Check row count
SELECT COUNT(*) FROM silver.incremental_transactions;
-- Expected: 45,000

-- Verify no duplicates
SELECT COUNT(*) - COUNT(DISTINCT transaction_id) as duplicates
FROM silver.incremental_transactions;
-- Expected: 0
```

---

### Step 2: Silver → Gold Dimensions

**Goal:** Load `dim_merchants` incrementally using SCD Type 1 (overwrite).

**Scripts:**
- `FILE 16 create_unknown_dimension_records.sql` - Insert -1 Unknown records
- `FILE 17 create_watermark_silver_to_gold_dims.sql` - Initialize watermark
- `FILE 18 load_dim_merchants_scd_type1.sql` - Load dimension
- `FILE 19 validate_dim_merchants.sql` - Validate results

**Pattern:**
```sql
DECLARE last_run_ts TIMESTAMP;
DECLARE effective_ts TIMESTAMP;
DECLARE max_existing_key INT64;

-- Load watermark
SET last_run_ts = (
  SELECT last_run_ts 
  FROM watermarks 
  WHERE job_name = 'silver_to_gold_dims'
);

SET effective_ts = TIMESTAMP_SUB(last_run_ts, INTERVAL 2 HOUR);

-- Get max surrogate key
SET max_existing_key = (
  SELECT COALESCE(MAX(merchant_key), 0)
  FROM dim_merchants
);

-- Build staging table with deduplication
CREATE OR REPLACE TABLE staging_dim_merchants AS
WITH latest_merchants AS (
  SELECT 
    merchant_id,
    merchant_name,
    updated_at,
    ROW_NUMBER() OVER (
      PARTITION BY merchant_id 
      ORDER BY updated_at DESC NULLS LAST
    ) as rn
  FROM silver.incremental_transactions
  WHERE (updated_at > effective_ts OR updated_at IS NULL)
    AND merchant_id IS NOT NULL
)
SELECT 
  ROW_NUMBER() OVER (ORDER BY merchant_id) + max_existing_key as merchant_key,
  merchant_id,
  merchant_name,
  updated_at
FROM latest_merchants
WHERE rn = 1;

-- MERGE into dimension (SCD Type 1)
MERGE dim_merchants D
USING staging_dim_merchants S
ON D.merchant_id = S.merchant_id

WHEN MATCHED THEN 
  UPDATE SET 
    merchant_name = S.merchant_name,
    updated_at = S.updated_at

WHEN NOT MATCHED THEN
  INSERT (merchant_key, merchant_id, merchant_name, ...)
  VALUES (S.merchant_key, S.merchant_id, S.merchant_name, ...);
```

**Why staging table?**
- ✅ Deduplication (one row per merchant)
- ✅ Easier debugging (inspect staging before MERGE)
- ✅ Key generation (sequential surrogate keys)
- ✅ Validation (check staging first)

**Validation:**
```sql
-- Check total merchants
SELECT COUNT(*) FROM dim_merchants;
-- Expected: 501 (500 + 1 Unknown)

-- Verify no duplicates
SELECT merchant_id, COUNT(*)
FROM dim_merchants
GROUP BY merchant_id
HAVING COUNT(*) > 1;
-- Expected: 0 rows
```

---

### Step 3: Silver → Gold Facts

**Goal:** Load `fact_transactions` with dimension lookups and unknown key handling.

**Scripts:**
- `FILE 20 create_watermark_silver_to_gold_fact.sql` - Initialize watermark
- `FILE 21 load_fact_transactions.sql` - Load facts
- `FILE 22 validate_fact_transactions.sql` - Validate results

**Pattern:**
```sql
DECLARE last_run_ts TIMESTAMP;
DECLARE effective_ts TIMESTAMP;

-- Load watermark
SET last_run_ts = (
  SELECT last_run_ts 
  FROM watermarks 
  WHERE job_name = 'silver_to_gold_fact'
);

SET effective_ts = TIMESTAMP_SUB(last_run_ts, INTERVAL 2 HOUR);

-- Build staging with dimension lookups
CREATE OR REPLACE TABLE staging_fact_transactions AS
WITH deduplicated_silver AS (
  SELECT *,
    ROW_NUMBER() OVER (
      PARTITION BY transaction_id 
      ORDER BY updated_at DESC NULLS LAST
    ) as rn
  FROM silver.incremental_transactions
  WHERE (updated_at > effective_ts OR updated_at IS NULL)
)
SELECT
  COALESCE(c.customer_key, -1) as customer_key,
  COALESCE(m.merchant_key, -1) as merchant_key,
  COALESCE(pm.payment_method_key, -1) as payment_method_key,
  COALESCE(s.status_key, -1) as status_key,
  COALESCE(l.location_key, -1) as location_key,
  COALESCE(d.date_key, -1) as date_key,
  t.transaction_id,
  t.product_category,
  t.amount,
  t.fee_amount,
  ...
FROM deduplicated_silver t
LEFT JOIN dim_customers c 
  ON t.customer_id = c.customer_id AND c.is_current = TRUE
LEFT JOIN dim_merchants m 
  ON t.merchant_id = m.merchant_id
LEFT JOIN dim_payment_methods pm 
  ON t.payment_method = pm.payment_method_name
LEFT JOIN dim_transaction_status s 
  ON t.transaction_status = s.status_name
LEFT JOIN dim_location l 
  ON t.location_type = l.location_type
LEFT JOIN dim_date d 
  ON DATE(t.transaction_timestamp) = d.full_date
WHERE t.rn = 1;

-- MERGE into fact table
MERGE fact_transactions F
USING staging_fact_transactions S
ON F.transaction_id = S.transaction_id

WHEN MATCHED THEN
  UPDATE SET 
    status_key = S.status_key,
    amount = S.amount,
    updated_at = S.updated_at

WHEN NOT MATCHED THEN
  INSERT (...) VALUES (...);
```

**Unknown key strategy:**

Use `COALESCE(dimension_key, -1)` to handle missing lookups:

- ✅ Fact table never has NULL foreign keys
- ✅ Easy to identify and fix missing dimensions
- ✅ Queries don't fail on NULL joins
- ✅ `-1` records pre-inserted in all dimensions

**Validation:**
```sql
-- Check total facts
SELECT COUNT(*) FROM fact_transactions;
-- Expected: 45,000

-- Check for unknown keys
SELECT 
  COUNTIF(customer_key = -1) as unknown_customers,
  COUNTIF(merchant_key = -1) as unknown_merchants
FROM fact_transactions;
-- Expected: 45K customers (temporary), 0 merchants

-- Verify revenue reconciliation
SELECT 
  (SELECT SUM(amount) FROM silver.incremental_transactions) as silver_amount,
  (SELECT SUM(amount) FROM fact_transactions) as gold_amount;
-- Amounts should match
```

---

### Step 4: End-to-End Pipeline

**Goal:** Run complete pipeline (Bronze→Silver→Dims→Facts) in one execution.

**Script:** `FILE 25 workflow2_complete_pipeline.sql`

**Execution order:**
1. Bronze → Silver (MERGE with watermark)
2. Silver → Dims (load dim_merchants)
3. Silver → Facts (load fact_transactions)
4. Update all 3 watermarks
5. Run validation queries

**Pattern:**
```sql
-- STEP 1: Bronze → Silver
-- (Full MERGE logic from FILE 09)

-- STEP 2: Silver → Dims
-- (Full dimension load from FILE 18)

-- STEP 3: Silver → Facts
-- (Full fact load from FILE 21)

-- STEP 4: Validation Summary
SELECT 
  'PIPELINE COMPLETE' as status,
  (SELECT COUNT(*) FROM silver.incremental_transactions) as silver_rows,
  (SELECT COUNT(*) FROM dim_merchants) as merchants,
  (SELECT COUNT(*) FROM fact_transactions) as facts,
  (SELECT last_run_ts FROM watermarks WHERE job_name='bronze_to_silver') as bronze_watermark,
  (SELECT last_run_ts FROM watermarks WHERE job_name='silver_to_gold_dims') as dims_watermark,
  (SELECT last_run_ts FROM watermarks WHERE job_name='silver_to_gold_fact') as fact_watermark;
```

**Validation:**
- ✅ All 3 watermarks advanced
- ✅ No duplicates in any layer
- ✅ Revenue reconciles across layers
- ✅ All foreign keys resolved (no -1 except customers)

---

## ☁️ Cloud Workflows Automation

### Deployment

**Scripts:** `workflows/`
- `create-tables-workflow.yaml` - One-time setup
- `daily-etl-workflow.yaml` - Daily pipeline
- `README.md` - Deployment guide

**Deploy workflows:**
```bash
cd workflows/

# Deploy setup workflow (run once)
gcloud workflows deploy create-tables-workflow \
  --source=create-tables-workflow.yaml \
  --location=us-central1

# Deploy daily ETL workflow
gcloud workflows deploy daily-etl-workflow \
  --source=daily-etl-workflow.yaml \
  --location=us-central1
```

**Schedule daily execution:**
```bash
gcloud scheduler jobs create http daily-etl-job \
  --location=us-central1 \
  --schedule="0 2 * * *" \
  --time-zone="America/New_York" \
  --uri="https://workflowexecutions.googleapis.com/v1/projects/YOUR_PROJECT/locations/us-central1/workflows/daily-etl-workflow/executions" \
  --http-method=POST \
  --oauth-service-account-email=YOUR_SERVICE_ACCOUNT@YOUR_PROJECT.iam.gserviceaccount.com
```

**Monitor execution:**
```bash
# List recent executions
gcloud workflows executions list \
  --workflow=daily-etl-workflow \
  --location=us-central1 \
  --limit=10

# Get execution details
gcloud workflows executions describe EXECUTION_ID \
  --workflow=daily-etl-workflow \
  --location=us-central1
```

---

## 📊 Production Monitoring

### Key Metrics to Track

**Data Quality:**
```sql
-- Check for duplicates
SELECT 
  'silver' as layer,
  COUNT(*) - COUNT(DISTINCT transaction_id) as duplicates
FROM silver.incremental_transactions
UNION ALL
SELECT 
  'gold',
  COUNT(*) - COUNT(DISTINCT transaction_id)
FROM fact_transactions;
-- Expected: 0 duplicates in both layers
```

**Watermark Status:**
```sql
SELECT 
  job_name,
  last_run_ts,
  TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), last_run_ts, HOUR) as hours_since_last_run,
  CASE 
    WHEN TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), last_run_ts, HOUR) > 25 THEN '🚨 STALE'
    WHEN TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), last_run_ts, HOUR) > 12 THEN '⚠️ WARNING'
    ELSE '✅ FRESH'
  END as status
FROM watermarks
ORDER BY job_name;
```

**Revenue Reconciliation:**
```sql
SELECT 
  (SELECT ROUND(SUM(amount), 2) FROM silver.incremental_transactions) as silver_amount,
  (SELECT ROUND(SUM(amount), 2) FROM fact_transactions) as gold_amount,
  ABS((SELECT SUM(amount) FROM silver.incremental_transactions) - 
      (SELECT SUM(amount) FROM fact_transactions)) as difference;
-- Difference should be 0.00
```

**Unknown Keys:**
```sql
SELECT 
  COUNTIF(customer_key = -1) as unknown_customers,
  COUNTIF(merchant_key = -1) as unknown_merchants,
  COUNTIF(payment_method_key = -1) as unknown_payment_methods
FROM fact_transactions;
-- Merchants/payment methods should be 0
```

---

## 🎓 Production Best Practices

### Load Order

**Critical:** Always load dimensions BEFORE facts.

```
1. Bronze → Silver (transactions)
2. Silver → Dims (merchants, customers, etc.)
3. Silver → Facts (fact_transactions with lookups)
```

Why?
- Facts depend on dimension keys
- Dimension loads can create new keys
- Loading facts first causes unknown keys (-1)

### Watermark Management

**Separate watermarks per job:**
- `bronze_to_silver` - Tracks Bronze processing
- `silver_to_gold_dims` - Tracks dimension updates
- `silver_to_gold_fact` - Tracks fact loads

**Safety gaps:**
- 2-hour lookback (catches most late arrivals)
- 7-day MERGE window (self-healing)
- NULL handling (don't skip missing timestamps)

### Staging Pattern

**Always use staging tables for:**
- Dimension loads (deduplication + key generation)
- Fact loads (dimension lookups + validation)
- Complex transformations (easier debugging)

Benefits:
- ✅ Inspect data before MERGE
- ✅ Validate transformations
- ✅ Easier rollback on errors
- ✅ Clear audit trail

### Unknown Key Strategy

**Pre-insert -1 records in ALL dimensions:**
```sql
INSERT INTO dim_merchants VALUES 
  (-1, 'UNKNOWN', 'Unknown Merchant', ...);
```

**Use COALESCE in fact loads:**
```sql
COALESCE(m.merchant_key, -1) as merchant_key
```

Benefits:
- ✅ Never NULL foreign keys
- ✅ Queries don't fail on missing lookups
- ✅ Easy to identify data quality issues
- ✅ Can fix retroactively

---

## 📋 Production Deployment Checklist

**Before deploying to production:**

**Code Review:**
- [ ] All DECLARE statements at top
- [ ] Partition filters in WHEN MATCHED
- [ ] Static predicates (no subqueries)
- [ ] NULL handling (`OR updated_at IS NULL`)
- [ ] Safety gaps (2-hour lookback)

**Testing:**
- [ ] Run on sample data (Day 1-3)
- [ ] Validate row counts match
- [ ] Check for duplicates
- [ ] Revenue reconciliation passes
- [ ] No unknown keys (except expected)

**Monitoring Setup:**
- [ ] Watermark status alerts
- [ ] Duplicate detection queries
- [ ] Revenue reconciliation checks
- [ ] Cloud Workflows monitoring
- [ ] Error notification (email/Slack)

**Documentation:**
- [ ] Pipeline architecture documented
- [ ] Load order documented
- [ ] Failure recovery procedures
- [ ] On-call runbook created

**Deployment:**
- [ ] Cloud Workflows deployed
- [ ] Scheduler configured (2 AM daily)
- [ ] Service account permissions verified
- [ ] Test execution completed
- [ ] Production cutover plan ready

---

## 🔗 Related Resources

### Blog Posts

- **Blog 1:** [Building a Payment Gateway Data Warehouse](#) - Initial dimensional model
- **Blog 2A:** [4 SQL Strategies](#) - Strategy theory and comparison
- **Blog 2B:** [Production Implementation](#) - This guide (complete pipeline)

### Code References

**All scripts in:** `sql/blog2_incremental_strategies/`

**Key files for Blog 2B:**
- `FILE 09` - daily_incremental_merge_watermark.sql (Bronze→Silver pattern)
- `FILE 16` - create_unknown_dimension_records.sql
- `FILE 17` - create_watermark_silver_to_gold_dims.sql
- `FILE 18` - load_dim_merchants_scd_type1.sql
- `FILE 19` - validate_dim_merchants.sql
- `FILE 20` - create_watermark_silver_to_gold_fact.sql
- `FILE 21` - load_fact_transactions.sql
- `FILE 22` - validate_fact_transactions.sql
- `FILE 25` - workflow2_complete_pipeline.sql
- `FILE 26` - end_to_end_validation.sql

**Workflows:**
- `workflows/create-tables-workflow.yaml`
- `workflows/daily-etl-workflow.yaml`
- `workflows/README.md`

### Additional Documentation

- `docs/blog2a_strategies.md` - Strategy theory (Blog 2A)
- `sql/blog2_incremental_strategies/README.md` - Complete folder guide
- `docs/troubleshooting.md` - Common issues

---

## 💬 Questions or Issues?

**Found a bug or have a question?**

- 📧 Email: mohamedkashifuddin24@gmail.com
- 💬 LinkedIn: [@mohamedkashifuddin](https://www.linkedin.com/in/mohamedkashifuddin/)
- 📝 Medium: [@mohamed_kashifuddin](https://medium.com/@mohamed_kashifuddin)

**Want to contribute?**
- Fork the repository
- Submit a pull request
- Open an issue on GitHub

---

**Last Updated:** November 2025  
**Part of:** Payment Gateway Data Engineering Series (Blog 2B)  
**Previous:** Blog 2A - Strategy Theory  
**Next:** Blog 3 - delta-lake-gcp-setup