
# Dataset: Digital Wallet Transactions

This folder contains (or should contain) the payment gateway transaction dataset used in this project.

---

## Download Instructions

### Step 1: Get Kaggle Account

If you don't have a Kaggle account:
1. Visit [kaggle.com](https://www.kaggle.com)
2. Sign up for free account
3. Verify your email

### Step 2: Download Dataset

**Dataset:** Digital Wallet Transactions  
**Source:** Kaggle  
**URL:** [https://www.kaggle.com/datasets/harunrai/digital-wallet-transactions](https://www.kaggle.com/datasets/harunrai/digital-wallet-transactions)

**Download steps:**
1. Visit the dataset URL above
2. Click "Download" button (requires Kaggle login)
3. Extract ZIP file
4. Place `digital_wallet_transactions.csv` in this `data/` folder

### Step 3: Verify File

**Expected file:**
- **Name:** `digital_wallet_transactions.csv`
- **Size:** ~500 KB
- **Rows:** 5,000 (including header)
- **Columns:** 17

**Quick verification:**

```bash
# Check file exists
ls -lh digital_wallet_transactions.csv

# Check row count (Mac/Linux)
wc -l digital_wallet_transactions.csv
# Expected: 5001 (5000 data rows + 1 header)

# View first few rows
head -5 digital_wallet_transactions.csv
```

---

## Dataset Schema

Once downloaded, your CSV should have these columns:

| Column | Type | Sample Value |
|--------|------|--------------|
| `idx` | INTEGER | 1 |
| `transaction_id` | STRING | "4dac3ea3-6492-46ec-80b8-dc45c3ad0b14" |
| `user_id` | STRING | "USER_05159" |
| `transaction_date` | TIMESTAMP | "19-08-2023 03:32" |
| `product_category` | STRING | "Rent Payment" |
| `product_name` | STRING | "2BHK Flat Deposit" |
| `merchant_name` | STRING | "Airbnb" |
| `product_amount` | FLOAT | 1525.39 |
| `transaction_fee` | FLOAT | 36.69 |
| `cashback` | FLOAT | 19.19 |
| `loyalty_points` | INTEGER | 186 |
| `payment_method` | STRING | "Debit Card" |
| `transaction_status` | STRING | "Successful" |
| `merchant_id` | STRING | "MERCH_0083" |
| `device_type` | STRING | "iOS" |
| `location` | STRING | "Urban" |

---

## Dataset Characteristics

### Transaction Distribution

- **Total Transactions:** 5,000
- **Date Range:** August 19, 2023 to August 18, 2024 (1 year)
- **Successful:** 4,755 (95.1%)
- **Failed:** 146 (2.9%)
- **Pending:** 99 (2.0%)

### Payment Methods

- UPI: ~1,000 transactions
- Credit Card: ~990 transactions
- Debit Card: ~1,020 transactions
- Wallet Balance: ~940 transactions
- Bank Transfer: ~1,050 transactions

### Geographic Distribution

- Urban: ~60%
- Suburban: ~25%
- Rural: ~15%

### Devices

- Android: ~50%
- iOS: ~45%
- Web: ~5%

---

## Data Quality Notes

### Known Issues

1. **Duplicate Merchant Names:** Same `merchant_id` can have multiple `merchant_name` values
   - Example: MERCH_0083 → "Airbnb", "Airbnb Hotels", "Airbnb Apartments"
   - **Solution:** Handled in `sql/03_gold_dim_merchants.sql` using `GROUP BY` + `ANY_VALUE()`

2. **Missing Currency:** Dataset doesn't specify currency
   - **Solution:** We add 'INR' (Indian Rupees) in Silver layer transformation

3. **No Refund Data:** All transactions show final status (no refund tracking)
   - **Solution:** We add placeholder columns (`is_refunded`, `refund_amount`) for future use

### Data Enhancements

In our pipeline, we add several columns not in the original CSV:

**Silver Layer Additions:**
- `currency` (default: 'INR')
- `loaded_at` (pipeline timestamp)
- `source_system` (default: 'kaggle_csv')

**Gold Layer Additions:**
- Surrogate keys for all dimensions
- Derived measures (net_customer_amount, merchant_net_amount, gateway_revenue)
- SCD Type 2 tracking columns (effective_start_date, effective_end_date, is_current)
- Additional flags (is_refunded, attempt_number)

---

## Alternative: Generate Synthetic Data

**Don't want to download from Kaggle?** You can generate synthetic payment data using Python:

```python
# Coming in Blog 3: synthetic_data_generator.py
# Will generate similar structure with configurable volume
```

**For Blog 1:** We recommend using the Kaggle dataset as-is to follow along exactly.

**For Blog 3 (benchmarking):** We'll show how to generate 10M, 100M, 1B rows for performance testing.

---

## Data Privacy & Usage

**This is synthetic/public data.** No real customer information included.

**Usage allowed:**
- ✅ Learning and educational purposes
- ✅ Testing and development
- ✅ Blog posts and tutorials
- ✅ Open-source projects

**Please:**
- Check Kaggle's terms of use
- Credit the dataset creator
- Don't claim this as production data

---

## Need Help?

**CSV not downloading?**
- Check if you're logged into Kaggle
- Try different browser
- Disable browser extensions (sometimes they block downloads)

**CSV looks different?**
- Dataset might have been updated
- Check column names match our schema above
- Minor differences OK (we handle in transformations)

**Still issues?**
- Open GitHub issue
- Comment on Medium blog post
- DM me on LinkedIn

---

**Last Updated:** November 2025  
**Dataset Version:** As of November 2025  
**Next Update:** Blog 3 (synthetic data generation)
