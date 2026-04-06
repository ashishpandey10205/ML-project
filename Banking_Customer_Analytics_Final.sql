
-- ============================================
-- Banking & Customer Analytics Project (Final)
-- Author: Ashish Pandey
-- Tool: MySQL Workbench
-- ============================================

CREATE DATABASE IF NOT EXISTS banking_projects;
USE banking_projects;

-- Tables assumed:
-- customers, transactions, accounts

 /*=========================
   SECTION 1: REVENUE
   ========================= */

-- Monthly revenue trend
SELECT DATE_FORMAT(t.transaction_date,'%Y-%m') AS ym,
       SUM(t.amount) AS monthly_revenue
FROM transactions t
GROUP BY DATE_FORMAT(t.transaction_date,'%Y-%m')
ORDER BY ym;

-- Revenue per city
SELECT c.city, SUM(t.amount) AS revenue
FROM customers c
JOIN transactions t ON c.customer_id = t.customer_id
GROUP BY c.city;

-- Revenue by merchant category
SELECT merchant_category, SUM(amount) AS revenue
FROM transactions
GROUP BY merchant_category;

-- Account-type revenue
SELECT a.account_type, SUM(t.amount) AS revenue
FROM accounts a
JOIN transactions t ON a.customer_id = t.customer_id
GROUP BY a.account_type;

-- Revenue split by gender
SELECT c.gender, SUM(t.amount) AS revenue
FROM customers c
JOIN transactions t ON c.customer_id = t.customer_id
GROUP BY c.gender;

-- Top 10% customers by spending
SELECT customer_id, spending
FROM (
    SELECT c.customer_id,
           SUM(t.amount) AS spending,
           NTILE(10) OVER(ORDER BY SUM(t.amount) DESC) AS bucket
    FROM customers c
    JOIN transactions t ON c.customer_id = t.customer_id
    GROUP BY c.customer_id
) x
WHERE bucket = 1;

-- Cities contributing more than 15% of total revenue
SELECT c.city, SUM(t.amount) AS total_revenue
FROM customers c
JOIN transactions t ON c.customer_id = t.customer_id
GROUP BY c.city
HAVING SUM(t.amount) > (SELECT 0.15 * SUM(amount) FROM transactions);

/* =========================
   SECTION 2: GROWTH
   ========================= */

-- Month-over-month revenue growth
SELECT ym, revenue,
       revenue - LAG(revenue) OVER(ORDER BY ym) AS mom_change
FROM (
    SELECT DATE_FORMAT(transaction_date,'%Y-%m') AS ym,
           SUM(amount) AS revenue
    FROM transactions
    GROUP BY DATE_FORMAT(transaction_date,'%Y-%m')
) a
ORDER BY ym;

-- City-wise MoM revenue growth
SELECT city, ym, revenue,
       revenue - LAG(revenue) OVER(PARTITION BY city ORDER BY ym) AS city_mom_growth
FROM (
    SELECT c.city,
           DATE_FORMAT(t.transaction_date,'%Y-%m') AS ym,
           SUM(t.amount) AS revenue
    FROM customers c
    JOIN transactions t ON c.customer_id = t.customer_id
    GROUP BY c.city, DATE_FORMAT(t.transaction_date,'%Y-%m')
) a
ORDER BY city, ym;

-- High-growth customers
SELECT customer_id, ym, revenue, mom_change
FROM (
    SELECT customer_id, ym, revenue,
           revenue - LAG(revenue) OVER(PARTITION BY customer_id ORDER BY ym) AS mom_change
    FROM (
        SELECT customer_id,
               DATE_FORMAT(transaction_date,'%Y-%m') AS ym,
               SUM(amount) AS revenue
        FROM transactions
        GROUP BY customer_id, DATE_FORMAT(transaction_date,'%Y-%m')
    ) x
) y
WHERE mom_change > 0;

-- City with fastest growth
SELECT city, mom_growth
FROM (
    SELECT city, ym, revenue,
           revenue - LAG(revenue) OVER(PARTITION BY city ORDER BY ym) AS mom_growth
    FROM (
        SELECT c.city,
               DATE_FORMAT(t.transaction_date,'%Y-%m') AS ym,
               SUM(t.amount) AS revenue
        FROM customers c
        JOIN transactions t ON c.customer_id = t.customer_id
        GROUP BY c.city, DATE_FORMAT(t.transaction_date,'%Y-%m')
    ) x
) y
ORDER BY mom_growth DESC
LIMIT 1;

/* =========================
   SECTION 3: RETENTION
   ========================= */

-- Customers inactive for 30+ days
SELECT customer_id, last_transaction_day,
       DATEDIFF(max_days, last_transaction_day) AS inactive_days
FROM (
    SELECT customer_id, MAX(transaction_date) AS last_transaction_day
    FROM transactions
    GROUP BY customer_id
) a
CROSS JOIN (
    SELECT MAX(transaction_date) AS max_days FROM transactions
) b
WHERE DATEDIFF(max_days, last_transaction_day) > 30;

-- Customer active months
SELECT customer_id,
       COUNT(DISTINCT DATE_FORMAT(transaction_date,'%Y-%m')) AS active_months
FROM transactions
GROUP BY customer_id;

-- Repeat purchase rate
SELECT COUNT(CASE WHEN txn_count > 1 THEN 1 END) * 100.0 / COUNT(*) AS repeat_purchase_rate
FROM (
    SELECT customer_id, COUNT(*) AS txn_count
    FROM transactions
    GROUP BY customer_id
) x;

-- Churn proxy (single-transaction customers)
SELECT customer_id
FROM transactions
GROUP BY customer_id
HAVING COUNT(*) = 1;

/* =========================
   SECTION 4: RISK
   ========================= */
use banking_projects
-- Fraud % month-over-month
SELECT ym, fraud_rate,
       fraud_rate - LAG(fraud_rate) OVER(ORDER BY ym) AS mom_fraud_change
FROM (
    SELECT DATE_FORMAT(transaction_date,'%Y-%m') AS ym,
           SUM(is_fraud) * 1.0 / COUNT(*) AS fraud_rate
    FROM transactions
    GROUP BY DATE_FORMAT(transaction_date,'%Y-%m')
) x
ORDER BY ym;

-- Fraud rate per city
SELECT c.city, SUM(t.is_fraud) * 1.0 / COUNT(*) AS fraud_rate
FROM transactions t
JOIN customers c ON c.customer_id = t.customer_id
GROUP BY c.city;

-- High-risk customers (bottom 20% credit score)
SELECT customer_id, credit_score
FROM (
    SELECT customer_id, credit_score,
           PERCENT_RANK() OVER(ORDER BY credit_score ASC) AS credit_percentile
    FROM customers
) x
WHERE credit_percentile <= 0.20;

-- Customers with balance higher than city average
SELECT c.customer_id, c.city, a.account_balance
FROM customers c
JOIN accounts a ON a.customer_id = c.customer_id
WHERE a.account_balance > (
    SELECT AVG(a2.account_balance)
    FROM accounts a2
    JOIN customers c2 ON c2.customer_id = a2.customer_id
    WHERE c2.city = c.city
);

/* =========================
   SECTION 5: SEGMENTATION
   ========================= */

-- Credit score segmentation
SELECT customer_id, credit_score,
       CASE
           WHEN credit_score < 550 THEN 'Low'
           WHEN credit_score BETWEEN 550 AND 650 THEN 'Medium'
           ELSE 'High'
       END AS credit_segment
FROM customers;

-- Balance bucketization
SELECT customer_id, account_balance,
       CASE
           WHEN account_balance < 20000 THEN 'Bucket_1_<20k'
           WHEN account_balance BETWEEN 20000 AND 50000 THEN 'Bucket_2_20k_50k'
           WHEN account_balance BETWEEN 50000 AND 100000 THEN 'Bucket_3_50k_100k'
           ELSE 'Bucket_4_100k_plus'
       END AS balance_bucket
FROM accounts;

-- END OF PROJECT
