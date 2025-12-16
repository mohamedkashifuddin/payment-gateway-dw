-- ===================================
-- QUERY 1: Monthly Revenue Trends
-- ===================================
-- Business Question: How does revenue vary month-to-month?

SELECT 
  d.year,
  d.month_name,
  COUNT(*) as transaction_count,
  ROUND(SUM(f.amount), 2) as total_revenue,
  ROUND(AVG(f.amount), 2) as avg_transaction_size,
  ROUND(SUM(f.fee_amount), 2) as total_fees,
  ROUND(SUM(f.cashback_amount), 2) as total_cashback
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.fact_transactions` f
JOIN `grand-jigsaw-476820-t1.payment_gateway_gold.dim_date` d 
  ON f.date_key = d.date_key
GROUP BY d.year, d.month_name, d.month_number
ORDER BY d.year, d.month_number;


-- ===================================
-- QUERY 2: Payment Method Performance
-- ===================================
-- Business Question: Which payment method has best success rate and lowest fees?

SELECT 
  p.payment_method_name,
  COUNT(*) as total_transactions,
  SUM(CASE WHEN ts.status_name = 'Successful' THEN 1 ELSE 0 END) as successful_count,
  ROUND(SUM(CASE WHEN ts.status_name = 'Successful' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS success_rate_pct,
  ROUND(AVG(f.fee_amount), 2) as avg_fee,
  ROUND(AVG(f.amount), 2) as avg_transaction_amount,
  ROUND(SUM(f.amount), 2) as total_volume
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.fact_transactions` f
JOIN `grand-jigsaw-476820-t1.payment_gateway_gold.dim_payment_methods` p 
  ON f.payment_method_key = p.payment_method_key
JOIN `grand-jigsaw-476820-t1.payment_gateway_gold.dim_transaction_status` ts 
  ON f.status_key = ts.status_key
GROUP BY p.payment_method_name
ORDER BY success_rate_pct DESC, total_volume DESC;


-- ===================================
-- QUERY 3: Top 10 Merchants by Revenue
-- ===================================
-- Business Question: Which merchants generate the most revenue?

SELECT 
  m.merchant_name,
  m.merchant_id,
  COUNT(*) as transaction_count,
  ROUND(SUM(f.amount), 2) as total_revenue,
  ROUND(AVG(f.amount), 2) as avg_transaction_size,
  ROUND(SUM(f.merchant_net_amount), 2) as merchant_net_revenue,
  ROUND(SUM(f.fee_amount), 2) as total_fees_paid
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.fact_transactions` f
JOIN `grand-jigsaw-476820-t1.payment_gateway_gold.dim_merchants` m 
  ON f.merchant_key = m.merchant_key
GROUP BY m.merchant_name, m.merchant_id
ORDER BY total_revenue DESC
LIMIT 10;


-- ===================================
-- QUERY 4: Weekend vs Weekday Analysis
-- ===================================
-- Business Question: Do we process more transactions on weekends or weekdays?

SELECT 
  CASE WHEN d.is_weekend THEN 'Weekend' ELSE 'Weekday' END AS day_type,
  COUNT(*) as transaction_count,
  ROUND(SUM(f.amount), 2) as total_revenue,
  ROUND(AVG(f.amount), 2) as avg_transaction_amount,
  ROUND(SUM(f.fee_amount), 2) as total_fees,
  ROUND(SUM(f.fee_amount) * 100.0 / SUM(f.amount), 2) as fee_percentage
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.fact_transactions` f
JOIN `grand-jigsaw-476820-t1.payment_gateway_gold.dim_date` d 
  ON f.date_key = d.date_key
GROUP BY d.is_weekend
ORDER BY transaction_count DESC;


-- ===================================
-- QUERY 5: Customer Segmentation (Top 20)
-- ===================================
-- Business Question: Which customers generate the most revenue?

SELECT 
  c.customer_id,
  COUNT(*) as transaction_count,
  ROUND(SUM(f.amount), 2) as total_spent,
  ROUND(AVG(f.amount), 2) as avg_transaction_size,
  ROUND(SUM(f.cashback_amount), 2) as total_cashback_received,
  SUM(f.loyalty_points) as total_loyalty_points,
  MAX(f.transaction_timestamp) as last_transaction_date
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.fact_transactions` f
JOIN `grand-jigsaw-476820-t1.payment_gateway_gold.dim_customers` c 
  ON f.customer_key = c.customer_key
WHERE c.is_current = TRUE
GROUP BY c.customer_id
ORDER BY total_spent DESC
LIMIT 20;


-- ===================================
-- QUERY 6: Transaction Status by Location
-- ===================================
-- Business Question: Does location affect success rate?

SELECT 
  l.location_type,
  ts.status_name,
  COUNT(*) as transaction_count,
  ROUND(SUM(f.amount), 2) as total_amount,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY l.location_type), 2) as pct_within_location
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.fact_transactions` f
JOIN `grand-jigsaw-476820-t1.payment_gateway_gold.dim_location` l 
  ON f.location_key = l.location_key
JOIN `grand-jigsaw-476820-t1.payment_gateway_gold.dim_transaction_status` ts 
  ON f.status_key = ts.status_key
GROUP BY l.location_type, ts.status_name
ORDER BY l.location_type, transaction_count DESC;


-- ===================================
-- QUERY 7: Product Category Performance
-- ===================================
-- Business Question: Which product categories generate most revenue?

SELECT 
  f.product_category,
  COUNT(*) as transaction_count,
  ROUND(SUM(f.amount), 2) as total_revenue,
  ROUND(AVG(f.amount), 2) as avg_amount,
  ROUND(SUM(f.cashback_amount), 2) as total_cashback,
  COUNT(DISTINCT f.customer_key) as unique_customers
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.fact_transactions` f
GROUP BY f.product_category
ORDER BY total_revenue DESC
LIMIT 15;


-- ===================================
-- QUERY 8: Device Type Usage Analysis
-- ===================================
-- Business Question: Which devices are most popular for transactions?

SELECT 
  f.device_type,
  COUNT(*) as transaction_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage,
  ROUND(SUM(f.amount), 2) as total_revenue,
  ROUND(AVG(f.amount), 2) as avg_transaction_size,
  ROUND(SUM(CASE WHEN ts.status_name = 'Successful' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as success_rate_pct
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.fact_transactions` f
JOIN `grand-jigsaw-476820-t1.payment_gateway_gold.dim_transaction_status` ts
  ON f.status_key = ts.status_key
GROUP BY f.device_type
ORDER BY transaction_count DESC;


-- ===================================
-- QUERY 9: Daily Transaction Pattern
-- ===================================
-- Business Question: What time patterns exist in transaction volume?

SELECT 
  d.day_of_week_name,
  d.day_of_week_number,
  COUNT(*) as transaction_count,
  ROUND(AVG(COUNT(*)) OVER (PARTITION BY d.is_weekend), 2) as avg_for_day_type,
  ROUND(SUM(f.amount), 2) as total_revenue
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.fact_transactions` f
JOIN `grand-jigsaw-476820-t1.payment_gateway_gold.dim_date` d 
  ON f.date_key = d.date_key
GROUP BY d.day_of_week_name, d.day_of_week_number, d.is_weekend
ORDER BY d.day_of_week_number;


-- ===================================
-- QUERY 10: Failed Transaction Analysis
-- ===================================
-- Business Question: Where are we losing transactions?

SELECT 
  p.payment_method_name,
  l.location_type,
  COUNT(*) as failed_count,
  ROUND(SUM(f.amount), 2) as lost_revenue,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as pct_of_failures
FROM `grand-jigsaw-476820-t1.payment_gateway_gold.fact_transactions` f
JOIN `grand-jigsaw-476820-t1.payment_gateway_gold.dim_payment_methods` p 
  ON f.payment_method_key = p.payment_method_key
JOIN `grand-jigsaw-476820-t1.payment_gateway_gold.dim_location` l 
  ON f.location_key = l.location_key
JOIN `grand-jigsaw-476820-t1.payment_gateway_gold.dim_transaction_status` ts 
  ON f.status_key = ts.status_key
WHERE ts.status_name = 'Failed'
GROUP BY p.payment_method_name, l.location_type
ORDER BY failed_count DESC
LIMIT 20;


-- ===================================
-- END OF ANALYTICS QUERIES
-- ===================================
-- Note: These are just examples! The star schema supports
-- unlimited combinations of dimensions and measures.