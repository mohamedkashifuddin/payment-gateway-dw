# Payment Gateway Data Model Documentation

**Version:** 1.0.0  
**Last Updated:** November 2025  
**Author:** Mohamed Kashifuddin

---

## Overview

This document provides detailed specifications for the payment gateway dimensional data model built using the Star Schema design pattern.

**Architecture:** Medallion (Bronze → Silver → Gold)  
**Design Pattern:** Star Schema  
**Model Type:** Dimensional (Fact + Dimensions)  
**Platform:** Google BigQuery

---

## Table of Contents

1. [Data Model Overview](#data-model-overview)
2. [Fact Table Specification](#fact-table-specification)
3. [Dimension Tables Specification](#dimension-tables-specification)
4. [Relationships & Cardinality](#relationships--cardinality)
5. [Design Decisions](#design-decisions)
6. [Data Quality Rules](#data-quality-rules)
7. [Future Enhancements](#future-enhancements)

---

## Data Model Overview

### Star Schema Diagram

```
                    dim_customers
                    (customer_key)
                          |
                          | 1:N
                          |
    dim_date -------- FACT_TRANSACTIONS -------- dim_merchants
   (date_key)       (5,000 rows)              (merchant_key)
       1:N               |                           1:N
                         |
            payment_method_key | status_key | location_key
                         |            |            |
                        1:N          1:N          1:N
                         |            |            |
            dim_payment_methods  dim_transaction_status  dim_location
```

### Layer Structure

| Layer | Dataset | Tables | Purpose |
|-------|---------|--------|---------|
| **Bronze** | `payment_gateway_bronze` | `raw_transactions` | Immutable source data |
| **Silver** | `payment_gateway_silver` | `cleaned_transactions` | Cleansed, validated data |
| **Gold** | `payment_gateway_gold` | 1 fact + 6 dimensions | Analytics-ready star schema |

---

## Fact Table Specification

### fact_transactions

**Purpose:** Central measurement table tracking payment transactions

**Grain:** One row per transaction attempt

**Partitioning:** None (for initial load; Blog 2 will add partitioning on transaction_timestamp)

**Clustering:** None (for initial load; will optimize in Blog 3)

---

### Columns

#### Foreign Keys (Link to Dimensions)

| Column | Type | Nullable | References | Description |
|--------|------|----------|------------|-------------|
| `customer_key` | INT64 | NO | dim_customers.customer_key | Customer who made transaction |
| `merchant_key` | INT64 | NO | dim_merchants.merchant_key | Merchant who received payment |
| `payment_method_key` | INT64 | NO | dim_payment_methods.payment_method_key | How payment was made |
| `status_key` | INT64 | NO | dim_transaction_status.status_key | Transaction outcome |
| `location_key` | INT64 | NO | dim_location.location_key | Where transaction occurred |
| `date_key` | INT64 | NO | dim_date.date_key | Date of transaction (YYYYMMDD) |

---

#### Degenerate Dimensions (Attributes in Fact)

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `transaction_id` | STRING | NO | Unique transaction identifier (natural key) |
| `product_category` | STRING | YES | Category of product/service purchased |
| `product_name` | STRING | YES | Name of product/service |
| `device_type` | STRING | YES | Device used (iOS, Android, Web) |

**Why degenerate?** These attributes:
- Don't warrant separate dimension tables (too granular)
- Are queried frequently alongside measures
- Don't have many-to-many relationships

---

#### Measures (Numeric Facts)

| Column | Type | Nullable | Description | Aggregation |
|--------|------|----------|-------------|-------------|
| `amount` | FLOAT64 | NO | Transaction amount (gross) | SUM, AVG |
| `fee_amount` | FLOAT64 | YES | Gateway processing fee | SUM, AVG |
| `cashback_amount` | FLOAT64 | YES | Cashback given to customer | SUM |
| `loyalty_points` | INT64 | YES | Loyalty points earned | SUM |

---

#### Derived Measures (Pre-Calculated)

| Column | Type | Formula | Description |
|--------|------|---------|-------------|
| `net_customer_amount` | FLOAT64 | `amount - cashback_amount` | What customer actually paid |
| `merchant_net_amount` | FLOAT64 | `amount - fee_amount` | What merchant receives |
| `gateway_revenue` | FLOAT64 | `fee_amount - cashback_amount` | Gateway profit/loss per transaction |

**Why pre-calculate?** These are queried frequently. Storing them eliminates computation in every query.

---

#### Timestamps (Critical for Incremental Loads)

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `transaction_timestamp` | TIMESTAMP | NO | When transaction occurred (business timestamp) |
| `loaded_at` | TIMESTAMP | NO | When record entered Silver layer |
| `created_at` | TIMESTAMP | NO | When record inserted into Gold fact table |
| `updated_at` | TIMESTAMP | NO | When record last modified |

**Blog 2-4 Note:** These timestamps enable all incremental load patterns.

---

#### Flags & Attributes

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `currency` | STRING | NO | 'INR' | Transaction currency |
| `is_refunded` | BOOLEAN | NO | FALSE | Has this transaction been refunded? |
| `refund_amount` | FLOAT64 | YES | NULL | Refund amount (if applicable) |
| `refund_date` | TIMESTAMP | YES | NULL | When refund processed |
| `attempt_number` | INT64 | NO | 1 | Retry attempt number |
| `source_system` | STRING | NO | 'kaggle_csv' | Source identifier |

---

### Sample Row

```json
{
  "customer_key": 2033,
  "merchant_key": 82,
  "payment_method_key": 3,
  "status_key": 3,
  "location_key": 3,
  "date_key": 20230819,
  "transaction_id": "4dac3ea3-6492-46ec-80b8-dc45c3ad0b14",
  "product_category": "Rent Payment",
  "product_name": "2BHK Flat Deposit",
  "device_type": "iOS",
  "amount": 1525.39,
  "fee_amount": 36.69,
  "cashback_amount": 19.19,
  "loyalty_points": 186,
  "net_customer_amount": 1506.20,
  "merchant_net_amount": 1488.70,
  "gateway_revenue": 17.50,
  "transaction_timestamp": "2023-08-19T03:32:00Z",
  "currency": "INR",
  "is_refunded": false,
  "refund_amount": null,
  "refund_date": null,
  "attempt_number": 1,
  "loaded_at": "2025-11-02T15:10:16Z",
  "source_system": "kaggle_csv",
  "created_at": "2025-11-07T11:25:00Z",
  "updated_at": "2025-11-07T11:25:00Z"
}
```

---

## Dimension Tables Specification

### 1. dim_customers

**Purpose:** Who made the transaction?

**Grain:** One row per unique customer per version (SCD Type 2 ready)

**SCD Type:** Type 2 (tracks historical changes)

**Rows:** ~1,000 unique customers

---

#### Columns

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `customer_key` (PK) | INT64 | NO | Surrogate key (auto-generated) |
| `customer_id` | STRING | NO | Natural key (business identifier) |
| `customer_name` | STRING | YES | Full name (placeholder - NULL in initial load) |
| `email` | STRING | YES | Email address (placeholder) |
| `phone` | STRING | YES | Phone number (placeholder) |
| `country` | STRING | YES | Country (placeholder) |
| `city` | STRING | YES | City (placeholder) |
| `customer_segment` | STRING | YES | Premium/Standard/Basic (placeholder) |
| `registration_date` | DATE | YES | When customer signed up (placeholder) |
| `is_verified` | BOOLEAN | YES | KYC verification status (placeholder) |
| `risk_score` | INT64 | YES | Fraud risk score 1-100 (placeholder) |
| `effective_start_date` | TIMESTAMP | NO | When this version became active |
| `effective_end_date` | TIMESTAMP | YES | When this version expired (NULL = current) |
| `is_current` | BOOLEAN | NO | Is this the current version? |
| `created_at` | TIMESTAMP | NO | When record created |
| `updated_at` | TIMESTAMP | NO | Last update timestamp |

**SCD Type 2 Usage:**
- When customer attributes change (e.g., risk_score updated), create new row
- Set `is_current = FALSE` on old row, `effective_end_date = CURRENT_TIMESTAMP()`
- Insert new row with `is_current = TRUE`, `effective_start_date = CURRENT_TIMESTAMP()`

**Sample Row:**
```json
{
  "customer_key": 1,
  "customer_id": "USER_00001",
  "customer_name": null,
  "email": null,
  "effective_start_date": "2025-11-07T05:00:00Z",
  "effective_end_date": null,
  "is_current": true
}
```

---

### 2. dim_merchants

**Purpose:** Who received the payment?

**Grain:** One row per unique merchant

**SCD Type:** Type 1 (overwrite on change)

**Rows:** 987 unique merchants

---

#### Columns

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `merchant_key` (PK) | INT64 | NO | Surrogate key |
| `merchant_id` | STRING | NO | Natural key (MERCH_XXXX) |
| `merchant_name` | STRING | NO | Business name |
| `business_type` | STRING | YES | E-commerce/SaaS/Retail (placeholder) |
| `industry` | STRING | YES | Electronics/Fashion/Food (placeholder) |
| `country` | STRING | YES | Operating country (placeholder) |
| `website` | STRING | YES | Merchant website (placeholder) |
| `onboarding_date` | DATE | YES | When merchant joined (placeholder) |
| `settlement_frequency` | STRING | YES | Daily/Weekly/Monthly (placeholder) |
| `is_active` | BOOLEAN | NO | Currently active? |
| `created_at` | TIMESTAMP | NO | Record created |
| `updated_at` | TIMESTAMP | NO | Last update |

**Critical Design Note:** Uses `GROUP BY merchant_id` + `ANY_VALUE(merchant_name)` to ensure uniqueness (see Blog 1 bug story).

---

### 3. dim_payment_methods

**Purpose:** How was payment made?

**Grain:** One row per payment method type

**SCD Type:** Type 1

**Rows:** 5

---

#### Columns

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `payment_method_key` (PK) | INT64 | NO | Surrogate key (1-5) |
| `payment_method_name` | STRING | NO | UPI, Credit Card, Debit Card, Wallet Balance, Bank Transfer |
| `method_type` | STRING | YES | Card/Bank/Digital Wallet (placeholder) |
| `requires_verification` | BOOLEAN | YES | 2FA/OTP required? (placeholder) |
| `average_processing_time_ms` | INT64 | YES | Typical processing time (placeholder) |
| `is_instant` | BOOLEAN | YES | Real-time settlement? (placeholder) |
| `created_at` | TIMESTAMP | NO | Record created |
| `updated_at` | TIMESTAMP | NO | Last update |

---

### 4. dim_transaction_status

**Purpose:** What was the transaction outcome?

**Grain:** One row per status type

**SCD Type:** Type 1

**Rows:** 3

---

#### Columns

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `status_key` (PK) | INT64 | NO | Surrogate key (1-3) |
| `status_name` | STRING | NO | Successful, Failed, Pending |
| `status_category` | STRING | NO | Success/Failed/Pending |
| `is_terminal` | BOOLEAN | NO | Is this a final state? (TRUE for Success/Failed) |
| `display_order` | INT64 | NO | For UI sorting (1=Pending, 2=Successful, 3=Failed) |
| `created_at` | TIMESTAMP | NO | Record created |

**Business Logic:**
- **is_terminal = TRUE:** Final states (Successful, Failed)
- **is_terminal = FALSE:** Pending (can transition to Success/Failed)

---

### 5. dim_location

**Purpose:** Where did the transaction occur?

**Grain:** One row per location type

**SCD Type:** Type 1

**Rows:** 3

---

#### Columns

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `location_key` (PK) | INT64 | NO | Surrogate key (1-3) |
| `location_type` | STRING | NO | Urban, Suburban, Rural |
| `region` | STRING | YES | Geographic region (placeholder) |
| `state` | STRING | YES | State/province (placeholder) |
| `country` | STRING | YES | Country (placeholder) |
| `timezone` | STRING | YES | Timezone (placeholder) |
| `created_at` | TIMESTAMP | NO | Record created |
| `updated_at` | TIMESTAMP | NO | Last update |

---

### 6. dim_date

**Purpose:** When did the transaction occur?

**Grain:** One row per calendar date

**SCD Type:** Type 0 (static, never changes)

**Rows:** 5,844 (2015-01-01 to 2030-12-31)

---

#### Columns

| Column | Type | Description |
|--------|------|-------------|
| `date_key` (PK) | INT64 | Date in YYYYMMDD format (20230819) |
| `full_date` | DATE | Actual date value |
| `day_of_month` | INT64 | 1-31 |
| `day_of_week_number` | INT64 | 1=Sunday, 7=Saturday |
| `day_of_week_name` | STRING | Monday, Tuesday, etc. |
| `week_of_year` | INT64 | 1-52 |
| `month_number` | INT64 | 1-12 |
| `month_name` | STRING | January, February, etc. |
| `quarter` | INT64 | 1-4 |
| `year` | INT64 | 2015-2030 |
| `is_weekend` | BOOLEAN | Saturday/Sunday = TRUE |
| `is_holiday` | BOOLEAN | Public holiday (placeholder - all FALSE) |
| `fiscal_year` | INT64 | Fiscal year (Apr-Mar) |
| `fiscal_quarter` | INT64 | Fiscal quarter |

**Why 2015-2030?** 
- Historical backfills (past data)
- Future transactions (next 5 years)
- Standard 15-year window for analytics

---

## Relationships & Cardinality

| Relationship | Type | Enforced By |
|--------------|------|-------------|
| dim_customers → fact_transactions | 1:N | LEFT JOIN on customer_key |
| dim_merchants → fact_transactions | 1:N | LEFT JOIN on merchant_key |
| dim_payment_methods → fact_transactions | 1:N | LEFT JOIN on payment_method_key |
| dim_transaction_status → fact_transactions | 1:N | LEFT JOIN on status_key |
| dim_location → fact_transactions | 1:N | LEFT JOIN on location_key |
| dim_date → fact_transactions | 1:N | LEFT JOIN on date_key |

**Note:** All relationships use LEFT JOIN (not INNER JOIN) to preserve fact rows even if dimension reference is missing.

---

## Design Decisions

### Why Star Schema (vs Snowflake)?

**Chosen:** Star Schema

**Reasoning:**
- ✅ Simpler structure (fewer JOINs)
- ✅ Faster query performance
- ✅ Easier for business users to understand
- ✅ Storage cost is negligible compared to query cost

**Trade-off:** Some data duplication in dimensions (e.g., merchant_name repeated for same merchant_id in source)

---

### Why Surrogate Keys (vs Natural Keys)?

**Chosen:** Integer surrogate keys (1, 2, 3...)

**Reasoning:**
- ✅ Faster JOIN performance (INT64 vs STRING)
- ✅ Smaller storage footprint
- ✅ Consistent pattern across all dimensions
- ✅ Supports SCD Type 2 (multiple versions of same natural key)

**Implementation:** `ROW_NUMBER() OVER (ORDER BY natural_key)`

---

### Why SCD Type 2 for Customers Only?

**Customers:** SCD Type 2 (track history)

**Reasoning:**
- Customer attributes change over time (risk_score, segment, email)
- Need to answer: "Was customer high-risk when this transaction happened?"
- Historical context matters for fraud analysis

**Other Dimensions:** SCD Type 1 (overwrite)

**Reasoning:**
- Merchant/payment method/status attributes rarely change
- Historical tracking not needed for business use cases
- Simpler maintenance

---

### Why Pre-Calculate Derived Measures?

**Chosen:** Store `net_customer_amount`, `merchant_net_amount`, `gateway_revenue`

**Reasoning:**
- ✅ These are queried in 80% of reports
- ✅ Eliminates repeated calculation
- ✅ Faster dashboard performance
- ❌ Slight storage increase (negligible)

---

## Data Quality Rules

### Fact Table

**Primary Key:** None (no natural composite key; transaction_id is degenerate dimension)

**Uniqueness Constraint:** `transaction_id` should be unique (validated via query, not enforced constraint)

**Validation Query:**
```sql
SELECT transaction_id, COUNT(*)
FROM fact_transactions
GROUP BY transaction_id
HAVING COUNT(*) > 1;
-- Expected: 0 rows
```

**Foreign Key Validation:**
```sql
SELECT 
  COUNT(*) as total_rows,
  COUNT(customer_key) as has_customer,
  COUNT(merchant_key) as has_merchant
FROM fact_transactions;
-- All counts should equal total_rows
```

---

### Dimension Tables

**Uniqueness Constraint:** Each dimension's natural key must be unique

**Validation Queries:**
```sql
-- Check dim_customers
SELECT customer_id, COUNT(*)
FROM dim_customers
WHERE is_current = TRUE
GROUP BY customer_id
HAVING COUNT(*) > 1;
-- Expected: 0 rows

-- Check dim_merchants
SELECT merchant_id, COUNT(*)
FROM dim_merchants
GROUP BY merchant_id
HAVING COUNT(*) > 1;
-- Expected: 0 rows
```

---

## Future Enhancements

**Planned for Blog 2-4:**

1. **Partitioning:**
   - Partition `fact_transactions` on `transaction_timestamp` (MONTH)
   - Enables partition pruning for incremental loads

2. **Clustering:**
   - Cluster on (`date_key`, `merchant_key`, `status_key`)
   - Optimizes common query patterns

3. **Incremental Load Columns:**
   - Add `batch_id` to track load batches
   - Add `is_deleted` flag for soft deletes

4. **Data Quality Dimensions:**
   - `dim_data_quality` to track DQ issues
   - Link to fact table via `dq_key` (nullable)

**Planned for Blog 5-6 (PySpark):**

5. **Delta Lake Integration:**
   - Convert to Delta format
   - Enable ACID transactions
   - Time travel capabilities

6. **Additional Dimensions:**
   - `dim_payment_gateways` (Razorpay, Stripe, etc.)
   - `dim_refund_reasons` (if refund data available)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | Nov 2025 | Initial release (Blog 1) |
| 1.1.0 | Dec 2025 | Incremental load support (Blog 2) - Planned |
| 2.0.0 | Dec 2025 | PySpark migration (Blog 5) - Planned |

---

**Document Owner:** Mohamed Kashifuddin  
**Last Review:** November 2025  
**Next Review:** December 2025 (Blog 2 release)