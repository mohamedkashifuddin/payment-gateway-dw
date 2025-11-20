# Troubleshooting Guide

Common issues and solutions when building the payment gateway data warehouse.

---

## Table of Contents

1. [Duplicate Rows in Fact Table](#duplicate-rows-in-fact-table)
2. [NULL Foreign Keys](#null-foreign-keys)
3. [Date Key Mismatch](#date-key-mismatch)
4. [CSV Upload Issues](#csv-upload-issues)
5. [Query Performance Problems](#query-performance-problems)
6. [Data Type Mismatches](#data-type-mismatches)

---

## Issue 1: Duplicate Rows in Fact Table

### Symptoms

- `fact_transactions` has more rows than `cleaned_transactions`
- Revenue numbers inflated 2x, 3x, or more
- Same `transaction_id` appears multiple times in fact table

### Diagnostic Query

```sql
-- Check if fact count matches Silver
SELECT 
  (SELECT COUNT(*) FROM payment_gateway_silver.cleaned_transactions) as silver_count,
  (SELECT COUNT(*) FROM payment_gateway_gold.fact_transactions) as fact_count,
  (SELECT COUNT(*) FROM payment_gateway_gold.fact_transactions) - 
  (SELECT COUNT(*) FROM payment_gateway_silver.cleaned_transactions) as difference;
```

If `difference > 0`, you have dimension duplication.

### Root Cause

**Duplicate rows in dimension tables**, most commonly `dim_merchants`.

When fact table joins to a dimension with duplicates:
- 1 transaction matches 3 merchant rows → 3 fact rows created

### Find the Problematic Dimension

```sql
-- Check dim_customers
SELECT customer_id, COUNT(*) as count
FROM payment_gateway_gold.dim_customers
WHERE is_current = TRUE
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- Check dim_merchants (most common culprit!)
SELECT merchant_id, COUNT(*) as count
FROM payment_gateway_gold.dim_merchants
GROUP BY merchant_id
HAVING COUNT(*) > 1;

-- Check dim_payment_methods
SELECT payment_method_name, COUNT(*) as count
FROM payment_gateway_gold.dim_payment_methods
GROUP BY payment_method_name
HAVING COUNT(*) > 1;

-- Check dim_location
SELECT location_type, COUNT(*) as count
FROM payment_gateway_gold.dim_location
GROUP BY location_type
HAVING COUNT(*) > 1;

-- Check dim_transaction_status
SELECT status_name, COUNT(*) as count
FROM payment_gateway_gold.dim_transaction_status
GROUP BY status_name
HAVING COUNT(*) > 1;
```

**Expected result:** 0 rows for all queries.

**If you find duplicates:** That's your problem dimension!

### Solution

Recreate the problematic dimension with `GROUP BY` to ensure uniqueness.

**Example: Fixing dim_merchants**

```sql
CREATE OR REPLACE TABLE payment_gateway_gold.dim_merchants AS
SELECT
  ROW_NUMBER() OVER (ORDER BY merchant_id) AS merchant_key,
  merchant_id,
  ANY_VALUE(merchant_name) AS merchant_name,  -- Pick one name
  NULL AS business_type,
  -- ... other columns ...
  CURRENT_TIMESTAMP() AS created_at,
  CURRENT_TIMESTAMP() AS updated_at
FROM payment_gateway_silver.cleaned_transactions
GROUP BY merchant_id;  -- ← This ensures one row per merchant_id
```

**Then recreate fact table:**

```sql
-- Run: sql/04_gold_fact_transactions.sql
```

**Verify fix:**

```sql
SELECT COUNT(*) FROM payment_gateway_gold.fact_transactions;
-- Should now equal Silver count (5,000)
```

---

## Issue 2: NULL Foreign Keys

### Symptoms

- Foreign keys in fact table are NULL
- Example: `customer_key IS NULL` for some rows
- Analytics queries return fewer rows than expected

### Diagnostic Query

```sql
-- Find which foreign keys have NULLs
SELECT 
  'customer_key' as dimension,
  COUNT(*) as null_count
FROM payment_gateway_gold.fact_transactions
WHERE customer_key IS NULL

UNION ALL

SELECT 
  'merchant_key' as dimension,
  COUNT(*) as null_count
FROM payment_gateway_gold.fact_transactions
WHERE merchant_key IS NULL

UNION ALL

SELECT 
  'payment_method_key' as dimension,
  COUNT(*) as null_count
FROM payment_gateway_gold.fact_transactions
WHERE payment_method_key IS NULL

UNION ALL

SELECT 
  'status_key' as dimension,
  COUNT(*) as null_count
FROM payment_gateway_gold.fact_transactions
WHERE status_key IS NULL

UNION ALL

SELECT 
  'location_key' as dimension,
  COUNT(*) as null_count
FROM payment_gateway_gold.fact_transactions
WHERE location_key IS NULL

UNION ALL

SELECT 
  'date_key' as dimension,
  COUNT(*) as null_count
FROM payment_gateway_gold.fact_transactions
WHERE date_key IS NULL;
```

**Expected:** 0 nulls for all dimensions.

### Root Cause

Dimension table is missing natural keys that exist in Silver table.

**Example:** Silver has `customer_id = 'USER_99999'` but `dim_customers` doesn't have this customer.

### Find Missing Natural Keys

```sql
-- Find customers in Silver but not in dimension
SELECT DISTINCT s.customer_id
FROM payment_gateway_silver.cleaned_transactions s
LEFT JOIN payment_gateway_gold.dim_customers d 
  ON s.customer_id = d.customer_id
WHERE d.customer_key IS NULL;

-- Find merchants in Silver but not in dimension
SELECT DISTINCT s.merchant_id
FROM payment_gateway_silver.cleaned_transactions s
LEFT JOIN payment_gateway_gold.dim_merchants m 
  ON s.merchant_id = m.merchant_id
WHERE m.merchant_key IS NULL;
```

### Solution

**Recreate the dimension** to include all natural keys from Silver:

```sql
-- Example: Recreate dim_customers with all customer_ids
CREATE OR REPLACE TABLE payment_gateway_gold.dim_customers AS
SELECT
  ROW_NUMBER() OVER (ORDER BY customer_id) AS customer_key,
  customer_id,
  -- ... other columns ...
FROM (
  SELECT DISTINCT customer_id
  FROM payment_gateway_silver.cleaned_transactions  -- ← Ensure all customers included
);
```

**Then recreate fact table.**

---

## Issue 3: Date Key Mismatch

### Symptoms

- `date_key IS NULL` in fact table
- Transactions from certain date ranges missing in analytics queries

### Diagnostic Query

```sql
-- Find transactions with NULL date_key
SELECT 
  transaction_id,
  transaction_timestamp,
  DATE(transaction_timestamp) as transaction_date
FROM payment_gateway_gold.fact_transactions
WHERE date_key IS NULL
LIMIT 10;
```

### Root Cause

Transaction dates fall outside `dim_date` range (2015-01-01 to 2030-12-31).

### Check Transaction Date Range

```sql
SELECT 
  MIN(DATE(transaction_timestamp)) as earliest_date,
  MAX(DATE(transaction_timestamp)) as latest_date
FROM payment_gateway_silver.cleaned_transactions;
```

**If dates are before 2015 or after 2030:** Need to extend `dim_date`.

### Solution

**Extend dim_date range** to cover your transaction dates:

```sql
-- Example: Extend to 2010-2035
CREATE OR REPLACE TABLE payment_gateway_gold.dim_date AS
SELECT
  CAST(FORMAT_DATE('%Y%m%d', date_value) AS INT64) AS date_key,
  date_value AS full_date,
  -- ... other columns ...
FROM UNNEST(GENERATE_DATE_ARRAY('2010-01-01', '2035-12-31', INTERVAL 1 DAY)) AS date_value
ORDER BY date_key;
```

**Then recreate fact table.**

---

## Issue 4: CSV Upload Issues

### Problem: BigQuery Can't Auto-Detect Schema

**Error:** "Could not parse CSV file"

**Causes:**
- Special characters in data (quotes, commas in text fields)
- Inconsistent date formats
- Mixed data types in same column

**Solution:**

1. **Manually specify schema** instead of auto-detect
2. Open CSV in text editor, check for issues
3. Use BigQuery's "Edit as text" for schema:

```json
[
  {"name": "idx", "type": "INTEGER"},
  {"name": "transaction_id", "type": "STRING"},
  {"name": "user_id", "type": "STRING"},
  {"name": "transaction_date", "type": "TIMESTAMP"},
  {"name": "product_category", "type": "STRING"},
  {"name": "product_name", "type": "STRING"},
  {"name": "merchant_name", "type": "STRING"},
  {"name": "product_amount", "type": "FLOAT"},
  {"name": "transaction_fee", "type": "FLOAT"},
  {"name": "cashback", "type": "FLOAT"},
  {"name": "loyalty_points", "type": "INTEGER"},
  {"name": "payment_method", "type": "STRING"},
  {"name": "transaction_status", "type": "STRING"},
  {"name": "merchant_id", "type": "STRING"},
  {"name": "device_type", "type": "STRING"},
  {"name": "location", "type": "STRING"}
]
```

### Problem: Upload Quota Exceeded

**Error:** "Upload quota exceeded"

**Solution:**
- Use Google Cloud Storage (GCS) for large files
- Upload CSV to GCS bucket
- Load from GCS to BigQuery

```bash
# Upload to GCS
gsutil cp digital_wallet_transactions.csv gs://your-bucket/data/

# Load to BigQuery
bq load --source_format=CSV \
  payment_gateway_bronze.raw_transactions \
  gs://your-bucket/data/digital_wallet_transactions.csv
```

---

## Issue 5: Query Performance Problems

### Problem: Queries Taking Too Long

**For Blog 1 (5,000 rows):** Queries should be instant (<1 second).

**If slow:**

1. **Check if you're querying the right layer:**
   - ✅ Gold layer queries should be fast
   - ❌ Don't query Bronze/Silver for analytics

2. **Ensure you're using foreign keys, not natural keys:**

**Slow (don't do this):**
```sql
SELECT COUNT(*)
FROM fact_transactions f
JOIN dim_merchants m ON f.merchant_id = m.merchant_id;  -- ❌ String join
```

**Fast (correct):**
```sql
SELECT COUNT(*)
FROM fact_transactions f
JOIN dim_merchants m ON f.merchant_key = m.merchant_key;  -- ✅ Integer join
```

3. **Check for Cartesian products** (missing JOIN conditions):

```sql
-- This will be VERY slow (10M x 1K = 10B rows!)
SELECT *
FROM fact_transactions, dim_customers;  -- ❌ Missing ON clause
```

---

## Issue 6: Data Type Mismatches

### Problem: "Cannot coerce type X to type Y"

**Common scenarios:**

### Scenario 1: Date Format Issues

**Error when creating Silver:**
```
Cannot coerce type TIMESTAMP to expected type STRING
```

**Cause:** `transaction_date` in Bronze is already TIMESTAMP, not STRING.

**Solution:**
```sql
-- Don't parse if already TIMESTAMP
transaction_date AS transaction_timestamp  -- Just rename

-- Only parse if it's STRING
PARSE_TIMESTAMP('%d-%m-%Y %H:%M', transaction_date) AS transaction_timestamp
```

**Check Bronze data type:**
```sql
SELECT column_name, data_type
FROM `grand-jigsaw-476820-t1.payment_gateway_bronze.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'raw_transactions'
  AND column_name = 'transaction_date';
```

### Scenario 2: Integer vs Float

**Error:** "Expected INT64, got FLOAT64"

**Solution:** Use explicit CAST:
```sql
CAST(amount AS INT64)  -- If you need integer
ROUND(amount, 2)       -- If you need 2 decimal places
```

---

## Still Having Issues?

### Debug Checklist

Run through this checklist systematically:

**Bronze Layer:**
- [ ] CSV uploaded successfully (5,000 rows)?
- [ ] All expected columns present?
- [ ] Date range correct (2023-08-19 to 2024-08-18)?

**Silver Layer:**
- [ ] Row count matches Bronze (5,000)?
- [ ] New columns populated (currency, loaded_at, source_system)?
- [ ] Data types correct (run INFORMATION_SCHEMA query)?

**Gold Dimensions:**
- [ ] Each dimension has no duplicate natural keys?
- [ ] dim_customers: ~1,000 rows?
- [ ] dim_merchants: 987 rows?
- [ ] dim_payment_methods: 5 rows?
- [ ] dim_transaction_status: 3 rows?
- [ ] dim_location: 3 rows?
- [ ] dim_date: 5,844 rows?

**Gold Fact:**
- [ ] Row count = 5,000 (matches Silver)?
- [ ] All foreign keys populated (no NULLs)?
- [ ] Sample query returns expected results?

---

## Getting Help

**If you're still stuck:**

1. **GitHub Issues:** Open an issue in the repository with:
   - Error message (full text)
   - Query you're running
   - Output of diagnostic queries

2. **Medium Comments:** Comment on Blog 1 with your question

3. **LinkedIn DM:** Message me directly: [Mohamed Kashifuddin](https://www.linkedin.com/in/mohamedkashifuddin/)

4. **Include these details:**
   - Which SQL script is failing?
   - Error message
   - Results of validation queries
   - BigQuery project/dataset names

---

**Last Updated:** November 2025  
**Version:** 1.0.0 (Blog 1)



