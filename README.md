# Payment Gateway Data Warehouse

**Part 1 of 6-Blog Series: Building Production-Ready Payment Gateway Analytics**

> 🎯 Learn to build a dimensional data warehouse from scratch using BigQuery, following industry-standard Medallion Architecture (Bronze → Silver → Gold).

[![Medium Blog](https://img.shields.io/badge/Medium-Blog%20Series-12100E?style=for-the-badge&logo=medium&logoColor=white)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![BigQuery](https://img.shields.io/badge/BigQuery-4285F4?style=for-the-badge&logo=google-cloud&logoColor=white)](#)

---

## 📚 Series Overview

This repository contains all code and documentation for the **Payment Gateway Data Engineering** blog series on Medium.

**Series:** [Payment Gateway Data Engineering: From CSV to Production-Scale Analytics](#)

### Blog Posts

| Part | Title | Status | Link |
|------|-------|--------|------|
| 1 | Building a Payment Gateway Data Warehouse from Scratch | ✅ Published | [Read Blog](#) |
| 2 | 5 SQL Mistakes That Break Incremental Loads | 🔜 Coming Soon | - |
| 3 | Benchmarking Incremental Load Strategies | 🔜 Coming Soon | - |
| 4 | Production-Ready Incremental Loads | 🔜 Coming Soon | - |
| 5 | When to Graduate from BigQuery SQL to PySpark | 🔜 Coming Soon | - |
| 6 | PySpark at Scale: Delta Lake & Optimization | 🔜 Coming Soon | - |

---

## 🎯 What You'll Build

A production-ready payment gateway data warehouse using:

- **Medallion Architecture** - Bronze → Silver → Gold layers
- **Star Schema** - 1 Fact table + 6 Dimension tables
- **Dimensional Modeling** - Proper fact/dimension design with SCD Type 2
- **BigQuery** - Serverless data warehouse on GCP
- **Sample Analytics** - Business-ready queries proving the model works

**Tech Stack:**
- Google BigQuery (data warehouse)
- SQL (data modeling & transformations)
- Kaggle Digital Wallet Transactions dataset (5,000 real transactions)

---

## 🚀 Quick Start

### Prerequisites

1. **GCP Account** - [Sign up for free tier](https://cloud.google.com/free) ($300 credit, 90 days)
2. **Kaggle Account** - [Download dataset](https://www.kaggle.com/datasets/harunrai/digital-wallet-transactions)
3. **Basic SQL Knowledge** - Comfortable with SELECT, JOIN, GROUP BY

### Setup Instructions

**Step 1: Clone the Repository**

```bash
git clone https://github.com/mohamedkashifuddin/payment-gateway-dw.git
cd payment-gateway-dw
```

**Step 2: Download Dataset**

1. Visit [Kaggle Digital Wallet Transactions](https://www.kaggle.com/datasets/harunrai/digital-wallet-transactions)
2. Download `digital_wallet_transactions.csv`
3. Place in `data/` folder

**Step 3: Create BigQuery Datasets**

Open BigQuery Console and run:

```sql
CREATE SCHEMA payment_gateway_bronze;
CREATE SCHEMA payment_gateway_silver;
CREATE SCHEMA payment_gateway_gold;
```

**Step 4: Run SQL Scripts in Order**

Execute scripts from the `sql/` folder in this order:

```bash
# 1. Load raw data (Bronze)
sql/01_bronze_raw_transactions.sql

# 2. Clean & transform (Silver)
sql/02_silver_cleaned_transactions.sql

# 3. Create dimensions (Gold)
sql/03_gold_dim_customers.sql
sql/03_gold_dim_merchants.sql
sql/03_gold_dim_payment_methods.sql
sql/03_gold_dim_transaction_status.sql
sql/03_gold_dim_location.sql
sql/03_gold_dim_date.sql

# 4. Create fact table (Gold)
sql/04_gold_fact_transactions.sql

# 5. Run analytics queries (validate)
sql/05_analytics_queries.sql
```

**Step 5: Validate Your Build**

Check that you have:
- ✅ 5,000 rows in `fact_transactions`
- ✅ ~1,000 unique customers
- ✅ 987 unique merchants
- ✅ All foreign keys populated (no NULLs)

---

## 📁 Repository Structure

```
payment-gateway-dw/
│
├── README.md                              # This file
├── LICENSE                                 # MIT License
│
├── data/
│   ├── README.md                          # Dataset download instructions
│   └── .gitkeep                           # Keep folder in git
│
├── sql/
│   ├── 01_bronze_raw_transactions.sql     # Bronze: Load raw CSV
│   ├── 02_silver_cleaned_transactions.sql # Silver: Clean & transform
│   ├── 03_gold_dim_customers.sql          # Gold: Customer dimension
│   ├── 03_gold_dim_merchants.sql          # Gold: Merchant dimension
│   ├── 03_gold_dim_payment_methods.sql    # Gold: Payment method dimension
│   ├── 03_gold_dim_transaction_status.sql # Gold: Status dimension
│   ├── 03_gold_dim_location.sql           # Gold: Location dimension
│   ├── 03_gold_dim_date.sql               # Gold: Date dimension (2015-2030)
│   ├── 04_gold_fact_transactions.sql      # Gold: Fact table (core)
│   └── 05_analytics_queries.sql           # Sample business queries
│
├── docs/
│   ├── data_model.md                      # Data model documentation
│   ├── architecture.md                    # Medallion architecture details
│   └── troubleshooting.md                 # Common issues & fixes
│
└── images/
    ├── star_schema_diagram.png            # ERD diagram
    ├── medallion_flow.png                 # Bronze/Silver/Gold flow
    └── sample_outputs/                     # Query result screenshots
```

---

## 🏗️ Data Model

### Star Schema Design

```
         dim_customers (~1,000 rows)
               |
        dim_merchants (987 rows) ---- FACT_TRANSACTIONS (5,000 rows) ---- dim_payment_methods (5 rows)
               |                                   |
         dim_location (3 rows)            dim_transaction_status (3 rows)
               |
          dim_date (5,844 rows)
```

### Fact Table: fact_transactions

**Grain:** One row per transaction

| Column Type | Columns |
|-------------|---------|
| **Foreign Keys** | customer_key, merchant_key, payment_method_key, status_key, location_key, date_key |
| **Measures** | amount, fee_amount, cashback_amount, loyalty_points |
| **Derived Measures** | net_customer_amount, merchant_net_amount, gateway_revenue |
| **Degenerate Dimensions** | transaction_id, product_category, product_name, device_type |
| **Timestamps** | transaction_timestamp, created_at, updated_at, loaded_at |
| **Flags** | currency, is_refunded, refund_amount, refund_date, attempt_number |

### Dimension Tables

| Dimension | Rows | Purpose | SCD Type |
|-----------|------|---------|----------|
| `dim_customers` | ~1,000 | Who made the transaction? | Type 2 (tracks changes) |
| `dim_merchants` | 987 | Who received the payment? | Type 1 (overwrite) |
| `dim_payment_methods` | 5 | How was payment made? | Type 1 |
| `dim_transaction_status` | 3 | Transaction outcome? | Type 1 |
| `dim_location` | 3 | Where did transaction occur? | Type 1 |
| `dim_date` | 5,844 | When (2015-2030)? | Type 0 (static) |

**Full documentation:** See [docs/data_model.md](docs/data_model.md)

---

## 📊 Sample Analytics Queries

Here are some example questions you can answer with this model:

### Monthly Revenue Trends

```sql
SELECT 
  d.year,
  d.month_name,
  COUNT(*) as transaction_count,
  ROUND(SUM(f.amount), 2) as total_revenue
FROM payment_gateway_gold.fact_transactions f
JOIN payment_gateway_gold.dim_date d ON f.date_key = d.date_key
GROUP BY d.year, d.month_name, d.month_number
ORDER BY d.year, d.month_number;
```

### Payment Method Performance

```sql
SELECT 
  p.payment_method_name,
  ROUND(SUM(CASE WHEN ts.status_name = 'Successful' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS success_rate_pct,
  ROUND(AVG(f.fee_amount), 2) as avg_fee
FROM payment_gateway_gold.fact_transactions f
JOIN payment_gateway_gold.dim_payment_methods p ON f.payment_method_key = p.payment_method_key
JOIN payment_gateway_gold.dim_transaction_status ts ON f.status_key = ts.status_key
GROUP BY p.payment_method_name
ORDER BY success_rate_pct DESC;
```

### Top Merchants by Revenue

```sql
SELECT 
  m.merchant_name,
  COUNT(*) as transaction_count,
  ROUND(SUM(f.amount), 2) as total_revenue
FROM payment_gateway_gold.fact_transactions f
JOIN payment_gateway_gold.dim_merchants m ON f.merchant_key = m.merchant_key
GROUP BY m.merchant_name
ORDER BY total_revenue DESC
LIMIT 10;
```

**More queries:** See [sql/05_analytics_queries.sql](sql/05_analytics_queries.sql)

---

## 🐛 Common Issues & Troubleshooting

### Issue 1: Duplicate Rows in Fact Table

**Symptom:** `fact_transactions` has more rows than `cleaned_transactions`

**Cause:** Duplicate rows in dimension tables (especially `dim_merchants`)

**Solution:** Run duplicate check on each dimension:

```sql
SELECT merchant_id, COUNT(*)
FROM payment_gateway_gold.dim_merchants
GROUP BY merchant_id
HAVING COUNT(*) > 1;
```

If duplicates found, recreate dimension with `GROUP BY`:

```sql
CREATE OR REPLACE TABLE dim_merchants AS
SELECT
  ROW_NUMBER() OVER (ORDER BY merchant_id) AS merchant_key,
  merchant_id,
  ANY_VALUE(merchant_name) AS merchant_name,
  ...
FROM cleaned_transactions
GROUP BY merchant_id;  -- ← Ensures uniqueness
```

**See:** [Blog Post Section - "The Bug Story"](#) for full walkthrough

---

### Issue 2: NULL Foreign Keys in Fact Table

**Symptom:** Some foreign keys are NULL (e.g., `customer_key IS NULL`)

**Cause:** Dimension doesn't have matching natural key from Silver table

**Solution:** Check which natural keys are missing:

```sql
-- Find customers in Silver but not in dimension
SELECT DISTINCT s.customer_id
FROM payment_gateway_silver.cleaned_transactions s
LEFT JOIN payment_gateway_gold.dim_customers d 
  ON s.customer_id = d.customer_id
WHERE d.customer_key IS NULL;
```

Then add missing rows to dimension.

---

### Issue 3: Date Key Mismatch

**Symptom:** `date_key IS NULL` in fact table

**Cause:** Date from transaction not in `dim_date` range (2015-2030)

**Solution:** Check transaction date range:

```sql
SELECT 
  MIN(DATE(transaction_timestamp)),
  MAX(DATE(transaction_timestamp))
FROM payment_gateway_silver.cleaned_transactions;
```

If dates fall outside 2015-2030, extend `dim_date` range and recreate.

**More troubleshooting:** See [docs/troubleshooting.md](docs/troubleshooting.md)

---

## 📖 Learning Resources

### Understanding the Concepts

- **Dimensional Modeling:** [Kimball's Star Schema](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/)
- **Medallion Architecture:** [Databricks Guide](https://www.databricks.com/glossary/medallion-architecture)
- **SCD Types:** [Slowly Changing Dimensions Explained](https://en.wikipedia.org/wiki/Slowly_changing_dimension)

### BigQuery Specific

- [BigQuery Documentation](https://cloud.google.com/bigquery/docs)
- [BigQuery Best Practices](https://cloud.google.com/bigquery/docs/best-practices-performance-overview)
- [BigQuery SQL Reference](https://cloud.google.com/bigquery/docs/reference/standard-sql/query-syntax)

### Payment Gateway Domain

- [Stripe API Documentation](https://stripe.com/docs/api)
- [Payment Gateway Basics](https://en.wikipedia.org/wiki/Payment_gateway)

---

## 🤝 Contributing

This repository is primarily for learning and following the blog series. However, contributions are welcome!

**Ways to contribute:**
- 🐛 Report bugs or issues
- 💡 Suggest improvements to SQL scripts
- 📝 Fix typos in documentation
- ⭐ Star the repo if you find it helpful!

**To contribute:**

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/improvement`)
3. Commit changes (`git commit -m 'Add improvement'`)
4. Push to branch (`git push origin feature/improvement`)
5. Open a Pull Request

---

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**TL;DR:** You're free to use, modify, and distribute this code, even commercially. Just include the original license.

---

## 👨‍💻 Author

**Mohamed Kashifuddin**  
Data Engineer | Analyst II at DXC Technology

Building production data pipelines at scale. Passionate about clean architecture, dimensional modeling, and sharing knowledge with the community.

**Connect with me:**

[![LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/mohamedkashifuddin/)
[![Medium](https://img.shields.io/badge/Medium-12100E?style=for-the-badge&logo=medium&logoColor=white)](https://medium.com/@mohamed_kashifuddin)
[![GitHub](https://img.shields.io/badge/GitHub-100000?style=for-the-badge&logo=github&logoColor=white)](https://github.com/mohamedkashifuddin)
[![Portfolio](https://img.shields.io/badge/Portfolio-FF7139?style=for-the-badge&logo=Firefox&logoColor=white)](https://mohamedkashifuddin.pages.dev)

📧 Email: mohamedkashifuddin24@gmail.com

---

## ⭐ Show Your Support

If this project helped you:

- ⭐ **Star this repository** - Helps others discover it
- 👏 **Clap on Medium** - [Read Blog 1](#)
- 🔗 **Share with your network** - Help other data engineers learn
- 💬 **Leave a comment** - Share your experience or ask questions

---

## 🔮 What's Coming Next

**Blog 2:** 5 SQL Mistakes That Break Incremental Loads  
*Dropping next week. Follow on Medium for updates!*

**Topics covered in the series:**
- Incremental load optimization (timestamp-based, CDC, MERGE)
- Performance benchmarking (10M, 100M, 1B rows)
- Production best practices (monitoring, data quality, late data)
- Scaling to PySpark on Dataproc (Blogs 5-6)

**Want to stay updated?**  
Watch this repository or follow me on Medium!

---

## 📊 Project Stats

![Stars](https://img.shields.io/github/stars/mohamedkashifuddin/payment-gateway-dw?style=social)
![Forks](https://img.shields.io/github/forks/mohamedkashifuddin/payment-gateway-dw?style=social)
![Issues](https://img.shields.io/github/issues/mohamedkashifuddin/payment-gateway-dw)
![Last Commit](https://img.shields.io/github/last-commit/mohamedkashifuddin/payment-gateway-dw)

---

## 🙏 Acknowledgments

- **Kaggle** for providing the Digital Wallet Transactions dataset
- **BigQuery** team for excellent documentation
- **Databricks** for pioneering the Medallion Architecture pattern
- **Kimball Group** for dimensional modeling best practices
- **The data engineering community** for continuous learning and sharing

---

**Happy Learning! 🚀**

*Remember: Green dashboards ≠ clean code. Build systems that outlast you.*

---

**Last Updated:** November 2025  
**Repository Version:** 1.0.0 (Blog 1)  
**Next Update:** Blog 2 release (expected: December 2025)