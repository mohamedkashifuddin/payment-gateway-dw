# Blog 2A: Incremental Load Strategies

**4 SQL Strategies That Prevent Incremental Load Failures (With Real Mistakes)**

> 📖 **Read the full blog post:** [Blog 2A on Medium](#)

This document provides a reference guide for the concepts covered in Blog 2A. For the complete tutorial with examples and explanations, read the blog post.

---

## 🎯 What Blog 2A Covers

Blog 2A focuses on **strategy theory and comparison**. It demonstrates four incremental load strategies using the Bronze→Silver layer of the payment gateway pipeline, showing common mistakes and their fixes.

### Learning Objectives

After reading Blog 2A, you should understand:

1. **The 4 incremental load strategies** and when to use each
2. **7 common SQL mistakes** that cause silent data loss
3. **Performance implications** of each strategy
4. **Cost optimization** through proper partition pruning
5. **Decision framework** for choosing the right strategy

### Primary Code Focus

- **Folder:** `sql/blog2_incremental_strategies/02_bronze_to_silver/`
- **Scripts:** FILES 04-11 (8 files demonstrating all strategies)
- **Dataset:** Day 1-3 CSV files with embedded data quality issues

---

## 📊 The 4 Incremental Load Strategies

### Strategy 1: Timestamp-Based Loading

**Best for:** Append-only data (logs, events, sensors)

**How it works:**
```sql
INSERT INTO silver.transactions
SELECT * FROM bronze.raw_transactions
WHERE updated_at > (SELECT MAX(updated_at) FROM silver.transactions);
```

**Pros:**
- Simple and fast
- Minimal overhead
- Easy to understand

**Cons:**
- Misses updates to existing records
- Requires careful NULL handling
- Vulnerable to late arrivals

**When to use:**
- Server logs
- Clickstream data
- IoT sensor readings
- Any data that never changes after creation

**Related scripts:**
- `FILE 04 day1_initial_load.sql` - Basic timestamp loading

---

### Strategy 2: MERGE (UPSERT) Loading

**Best for:** Data with updates (transactions, orders, profiles)

**How it works:**
```sql
MERGE silver.transactions T
USING bronze.raw_transactions S
ON T.transaction_id = S.transaction_id

WHEN MATCHED THEN UPDATE SET ...
WHEN NOT MATCHED THEN INSERT ...;
```

**Pros:**
- Handles INSERT + UPDATE in one statement
- Atomic operation (all-or-nothing)
- Prevents duplicates automatically
- Naturally handles late arrivals

**Cons:**
- More expensive than INSERT-only
- Requires proper partition pruning
- Complex predicate optimization

**When to use:**
- Payment transactions (status changes, refunds)
- Customer profiles (frequent updates)
- Order management (status tracking)
- Any data with updates after creation

**Related scripts:**
- `FILE 05 day2_merge_pattern_basic.sql` - Basic MERGE
- `FILE 06 day3_merge_with_updates.sql` - MERGE with updates
- `FILE 09 daily_incremental_merge_watermark.sql` - Production pattern

---

### Strategy 3: DELETE + INSERT Pattern

**Best for:** Daily batch reprocessing

**How it works:**
```sql
-- Step 1: Delete old data
DELETE FROM silver.transactions
WHERE DATE(transaction_timestamp) = '2024-11-02';

-- Step 2: Insert corrected data
INSERT INTO silver.transactions
SELECT * FROM bronze.raw_transactions_day2;
```

**Pros:**
- Simple and predictable
- Easy to debug
- Idempotent (run multiple times = same result)
- Works on any database

**Cons:**
- Temporary data gap during DELETE
- Requires careful WHERE clause validation
- Not atomic (two separate operations)

**When to use:**
- Daily batch corrections
- Partition-level reprocessing
- Recovery after data quality issues
- Non-BigQuery databases

**Related scripts:**
- `FILE 10 delete_insert_pattern.sql` - DELETE + INSERT demo

---

### Strategy 4: INSERT OVERWRITE Pattern

**Best for:** BigQuery partitioned tables

**How it works:**
```sql
INSERT INTO silver.transactions
SELECT * FROM bronze.raw_transactions_day3
WHERE DATE(transaction_timestamp) = '2024-11-03'
OVERWRITE PARTITIONS (DATE '2024-11-03');
```

**Pros:**
- Atomic partition replacement (no gap)
- Fast and efficient
- Concurrent queries always see consistent data
- No temporary unavailability

**Cons:**
- BigQuery-specific (not portable)
- Requires partitioned tables
- Can only overwrite entire partitions

**When to use:**
- BigQuery environments
- Partition-level reprocessing
- Production systems with strict uptime requirements
- When atomicity is critical

**Related scripts:**
- `FILE 11 insert_overwrite_pattern.sql` - INSERT OVERWRITE demo

---

## 🐛 The 7 SQL Mistakes

### Mistake #1: Late-Arriving Data

**Problem:** Transactions that occur on Day 1 arrive in the Day 2 batch, but timestamp filters exclude them.

**Dataset:** 150 late arrivals embedded in Day 2 data

**Bad code:**
```sql
WHERE updated_at > (SELECT MAX(updated_at) FROM silver.transactions)
```

**Fix:**
```sql
-- Add 2-hour lookback window
WHERE updated_at > TIMESTAMP_SUB(last_watermark, INTERVAL 2 HOUR)
```

**Related script:** `FILE 05 day2_merge_pattern_basic.sql`

---

### Mistake #2: NULL Timestamp Handling

**Problem:** Rows with NULL `updated_at` are silently skipped by comparison operators.

**Dataset:** 150 rows with NULL timestamps in Day 2

**Bad code:**
```sql
WHERE updated_at > last_watermark  -- Skips NULLs!
```

**Fix:**
```sql
WHERE updated_at > last_watermark 
   OR updated_at IS NULL  -- Explicitly include NULLs
```

**Related script:** `FILE 05 day2_merge_pattern_basic.sql`

---

### Mistake #3: Timezone Confusion

**Problem:** Source systems send timestamps in different timezones (EST vs UTC), causing partitioning issues.

**Dataset:** 88 rows with EST timestamps in Day 3

**Bad code:**
```sql
-- Assuming all timestamps are UTC (they're not!)
SELECT * FROM bronze.raw_transactions
```

**Fix:**
```sql
-- Standardize to UTC at ingestion
SELECT 
  TIMESTAMP_ADD(transaction_timestamp, INTERVAL 5 HOUR) as transaction_timestamp
FROM bronze.raw_transactions
```

**Related script:** `FILE 06 day3_merge_with_updates.sql`

---

### Mistake #4: Partition Pruning Failure

**Problem:** Placing partition filters in the ON clause prevents optimization and causes duplicates.

**Impact:** 4x cost increase (161 GB scanned instead of 41 GB)

**Bad code:**
```sql
MERGE silver.transactions T
USING bronze.raw_transactions S
ON T.transaction_id = S.transaction_id
   AND DATE(T.transaction_timestamp) >= '2024-11-01'  -- WRONG!
```

**Fix:**
```sql
MERGE silver.transactions T
USING bronze.raw_transactions S
ON T.transaction_id = S.transaction_id  -- Only match condition

WHEN MATCHED AND DATE(T.transaction_timestamp) >= '2024-11-01' THEN  -- Correct!
  UPDATE ...
```

**Related script:** `FILE 06 day3_merge_with_updates.sql`

---

### Mistake #5: Dynamic Predicates

**Problem:** Subqueries in predicates prevent query optimizer from pruning partitions.

**Bad code:**
```sql
WHEN MATCHED AND DATE(T.transaction_timestamp) >= (
  SELECT DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)  -- Evaluated per row!
) THEN UPDATE ...
```

**Fix:**
```sql
DECLARE min_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY);

WHEN MATCHED AND DATE(T.transaction_timestamp) >= min_date THEN  -- Static!
  UPDATE ...
```

**Related script:** `FILE 09 daily_incremental_merge_watermark.sql`

---

### Mistake #6: Dimension Update Handling

**Problem:** Merchant names change, but old transactions keep the old name, causing analytics inconsistency.

**Dataset:** 300 merchant name changes in Day 3

**Bad code:**
```sql
-- Only new transactions get the updated name
MERGE silver.transactions T
USING bronze.raw_transactions S
ON T.transaction_id = S.transaction_id
WHEN NOT MATCHED THEN INSERT ...  -- Old transactions unchanged
```

**Fix:**
```sql
-- Update existing transactions when merchant name changes
MERGE silver.transactions T
USING bronze.raw_transactions S
ON T.transaction_id = S.transaction_id

WHEN MATCHED AND T.merchant_name != S.merchant_name THEN
  UPDATE SET merchant_name = S.merchant_name
```

**Related script:** `FILE 06 day3_merge_with_updates.sql`

---

### Mistake #7: Missing WHERE Clause

**Problem:** DELETE statement without WHERE clause deletes entire table (500M rows in production).

**Horror Story:** Engineer debugging at 2 AM, comments out WHERE clause, runs query, deletes production table.

**Bad code:**
```sql
DELETE FROM silver.transactions;  -- Catastrophic!
```

**Fix:**
```sql
DECLARE expected_delete_count INT64 DEFAULT 15000;
DECLARE actual_delete_count INT64;

-- Validate before deleting
SET actual_delete_count = (
  SELECT COUNT(*) FROM silver.transactions
  WHERE DATE(transaction_timestamp) = '2024-11-02'
);

ASSERT actual_delete_count <= expected_delete_count * 1.1
  AS 'Delete count exceeds expected! Stopping.';

-- Only delete if assertion passed
DELETE FROM silver.transactions
WHERE DATE(transaction_timestamp) = '2024-11-02';
```

**Related script:** `FILE 10 delete_insert_pattern.sql`

---

## 📈 Performance Comparison

Based on real BigQuery metrics processing 45,000 payment transactions:

| Strategy | Data Scanned | Runtime | Cost (per run) | Relative Cost |
|----------|--------------|---------|----------------|---------------|
| Timestamp-Based | 2 GB | 3 sec | $0.01 | 1x (baseline) |
| MERGE (optimized) | 2 GB | 8 sec | $0.01 | 1x |
| MERGE (broken) | 161 GB | 45 sec | $0.80 | 80x |
| DELETE + INSERT | 3 GB | 5 sec | $0.015 | 1.5x |
| INSERT OVERWRITE | 2 GB | 3 sec | $0.01 | 1x |

**Key insight:** Proper partition pruning in MERGE reduces costs by 80x!

---

## 🎯 Decision Framework

### Decision Tree

```
START: Does your data get updated after creation?
│
├─ NO (append-only)
│  └─ Use TIMESTAMP-BASED
│     └─ Add lookback window if late arrivals common
│
└─ YES (updates happen)
   │
   └─ Are you reprocessing entire partitions?
      │
      ├─ YES (reprocess days/months)
      │  ├─ Using BigQuery? → Use INSERT OVERWRITE
      │  └─ Other database? → Use DELETE + INSERT (with ASSERT)
      │
      └─ NO (row-level updates)
         └─ Use MERGE
            ├─ Put partition filters in WHEN MATCHED
            ├─ Use static predicates (DECLARE)
            └─ Handle dimension updates explicitly
```

### Quick Reference Table

| If Your Data... | Use This Strategy |
|----------------|-------------------|
| Never updates after creation | Timestamp-Based |
| Updates frequently (status, refunds) | MERGE |
| Needs partition reprocessing (BigQuery) | INSERT OVERWRITE |
| Needs partition reprocessing (other DB) | DELETE + INSERT |
| Has late arrivals | MERGE or Timestamp + lookback |
| Has timezone issues | Fix at Bronze layer |
| Has dimension updates | MERGE with explicit updates |

---

## 📋 Production Checklist

Before deploying incremental loads to production:

**Code Structure:**
- [ ] All DECLARE statements at top of script
- [ ] Partition filters in WHEN MATCHED (not ON clause)
- [ ] Static predicates using DECLARE (no subqueries)
- [ ] Safety gap in watermark (2-hour lookback recommended)

**Data Quality:**
- [ ] NULL handling (`OR updated_at IS NULL`)
- [ ] Timezone standardization at Bronze layer
- [ ] Late arrival handling (lookback window or MERGE)
- [ ] Dimension update propagation

**Safety Checks:**
- [ ] ASSERT before DELETE operations
- [ ] Row count validation after load
- [ ] Duplicate detection queries
- [ ] Cross-layer reconciliation

**Performance:**
- [ ] Partition pruning validated (check EXPLAIN plan)
- [ ] Static predicates confirmed
- [ ] Wildcard tables for automatic file inclusion
- [ ] Staging tables for complex transformations

---

## 🔗 Related Resources

### Blog Posts

- **Blog 1:** [Building a Payment Gateway Data Warehouse](#) - Dimensional model setup
- **Blog 2A:** [4 SQL Strategies](#) - This guide (strategy theory)
- **Blog 2B:** [Production Implementation](#) - Complete Bronze→Silver→Gold pipeline

### Code References

**All scripts in:** `sql/blog2_incremental_strategies/`

**Key files for Blog 2A:**
- `FILE 04` - day1_initial_load.sql
- `FILE 05` - day2_merge_pattern_basic.sql
- `FILE 06` - day3_merge_with_updates.sql
- `FILE 07` - day3_validation_queries.sql
- `FILE 08` - backfill_day1_to_day3.sql
- `FILE 09` - daily_incremental_merge_watermark.sql (production)
- `FILE 10` - delete_insert_pattern.sql
- `FILE 11` - insert_overwrite_pattern.sql

### Additional Documentation

- `docs/blog2b_implementation.md` - Production pipeline guide (Blog 2B)
- `sql/blog2_incremental_strategies/README.md` - Complete folder documentation
- `workflows/README.md` - Cloud Workflows deployment

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
**Part of:** Payment Gateway Data Engineering Series (Blog 2A)  
**Next:** Blog 2B - Production Implementation