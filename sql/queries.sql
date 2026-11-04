-- Queries are ran through DB Browser

-- Basic Queries to get a sense of the data --
-- Monthly revenue and order count of delivered orders
SELECT strftime('%Y-%m', o.order_purchase_timestamp) AS month,
    COUNT(DISTINCT o.order_id)                    AS orders,
    ROUND(SUM(oi.price), 2)                       AS revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
GROUP BY month
ORDER BY month;

-- Findings: Data shows revenue increasing over time,
-- with a peak in 2017-11 with 987765.37 in revenue and 7289 orders.
-- Lowest revenue was in 2017-01 with 111798.36 in revenue and 750 orders.
-- Throughout 2018, revenue and order count decreased relative to the beginning of the year.

-- Top 10 product categories by revenue
SELECT COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(oi.price), 2)    AS revenue,
    ROUND(100.0 * SUM(oi.price) / SUM(SUM(oi.price)) OVER (), 2) AS pct_of_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
       ON p.product_category_name = t.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY category
ORDER BY revenue DESC
LIMIT 10

-- Findings: The top 10 categories by revenue are:
-- 1. health_beauty, 2. watches_gifts, 3. bed_bath_table,
-- 4. sports_leisure, 5. computers_accessories, 6. furntiture_deecor,
-- 7. housewares, 8. cool_stuff, 9. auto, 10. toys
-- With health_beauty being the highest revenue category with 1233131.72 in revenue and 8647 orders,
-- which contributes to 9.33% of total revenue.

-- Revenue and order count by customer state
SELECT c.customer_state AS state,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(oi.price), 2)    AS revenue,
    ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2) AS revenue_per_order,
	ROUND(100.0 * SUM(oi.price) / SUM(SUM(oi.price)) OVER (), 2) AS pct_of_revenue
FROM orders o
JOIN customers c    ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY revenue DESC;

-- Findings: The state with the most revenue is SP with 5067633.16 in revenue and 40501 orders
-- which contributes to 38.33% of total revenue, but has a lower revenue per order than RJ.

-- Average order value by month
SELECT strftime('%Y-%m', o.order_purchase_timestamp) AS month, 
	COUNT(DISTINCT o.order_id) AS orders,
	SUM(oi.price) AS revenue
	FROM orders o
	JOIN order_items oi ON o.order_id = oi.order_id
	WHERE o.order_status = 'delivered'
		AND o.order_purchase_timestamp >= '2017-01-01'
		AND o.order_purchase_timestamp <  '2018-09-01'
	GROUP BY month

SELECT month, orders, revenue, revenue * 1.0 / orders AS avg_order_value
FROM monthly
ORDER BY avg_order_value DESC

-- Findings: The month with the highest average order value is 2017-01 with an average order 
-- value of 149.06, but contained the least amount of orders and revenue.

-- Running total of revenue
WITH monthly AS (
    SELECT
        strftime('%Y-%m', o.order_purchase_timestamp) AS month,
        SUM(oi.price)                                 AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY month
)
SELECT
    month,
    ROUND(revenue, 2) AS revenue,
    ROUND(SUM(revenue) OVER (ORDER BY month), 2) AS running_total
FROM monthly
ORDER BY month;

-- Findings: The total revenue from 2017-01 to 2018-08 is 13181027.13.

-- Payment type breakdowns with share of total revenue
SELECT p.payment_type, 
	COUNT(DISTINCT p.order_id) AS orders,
	ROUND(SUM(p.payment_value)) AS total_value,
	ROUND(100.0 * SUM(p.payment_value) / SUM(SUM(p.payment_value)) OVER (), 2) AS pct_of_total
FROM order_payments p
JOIN orders o ON p.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY p.payment_type
ORDER BY total_value DESC

-- Findings: The payment type with the highest orders and total value is 
-- credit_card with 74304 orders and 78.46% of the total revenue.

-- Advanced Queries --
-- Reuseable CTE that gives one row per delivered order

WITH delivered_orders AS (
		 SELECT o.order_id,  
		 c.customer_unique_id,
		 o.order_purchase_timestamp,
		 o.order_delivered_customer_date,
		 (o.order_delivered_customer_date - o.order_purchase_timestamp) AS delivery_days,
		 (o.order_delivered_customer_date - o.order_estimated_delivery_date) AS days_late,
		 CASE
					WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1
					ELSE 0
		END AS is_late
		FROM orders o
		JOIN customers c ON o.customer_id = c.customer_id
		WHERE o.order_delivered_customer_date IS NOT NULL
)

SELECT COUNT(*) AS count, COUNT(order_delivered_customer_date) AS delivered_count
FROM delivered_orders

-- Checked that number of rows = number of delivered orders (96476 = 96476)


-- Delivery performance and reviews --
-- Overall late delivery rate and average days late for late deliveries
SELECT COUNT(*) FILTER (WHERE is_late = 1) AS late_count,
		ROUND(
        COUNT(*) FILTER (WHERE is_late = 1) * 100.0/ COUNT(*), 2
		) AS late_delivery_rate,
		ROUND(AVG(days_late) FILTER (WHERE is_late = 1), 2) AS avg_days_late
FROM delivered_orders

-- Findings: 7827 orders were delivered late, with a 8.11 late delivery rate and an average of 0.04 days late for late deliveries.

-- Late delivery rate by customer state, worst to best
SELECT c.customer_state, 
		ROUND(
        COUNT(*) FILTER (WHERE is_late = 1) * 100.0/ COUNT(*), 2
		) AS late_delivery_rate
		FROM delivered_orders o
		JOIN customers c ON  o.customer_unique_id = c.customer_unique_id
		GROUP BY c.customer_state
		ORDER BY late_delivery_rate ASC

-- Findings:

-- Average review score by delivery bucket: early, on time, 1-3 days late, 4-7 days late, 8+ days late
SELECT CASE 
			WHEN days_late < 0 THEN 'early'
			WHEN days_late = 0 THEN 'on time'
			WHEN days_late BETWEEN 1 AND 3 THEN '1-3 days late'
			WHEN days_late BETWEEN 4 AND 7 THEN '4-7 days late'
			ELSE '8+ days late'
		END AS delivery_bucket,
	ROUND(AVG(r.review_score), 2) AS avg_review
FROM delivered_orders o
JOIN order_reviews r ON o.order_id = r.order_id
GROUP BY delivery_bucket

-- Findings:

-- Review score for late vs. on-time orders, with average score and the share of 1-star reviews for each
SELECT CASE 
		    WHEN days_late = 0 THEN 'on time'
			WHEN days_late > 0 THEN 'late'
        END AS delivery_outcome,
	ROUND(AVG(r.review_score), 2) AS avg_review,
	COUNT(*) FILTER (WHERE r.review_score = 1) AS '1 stars'
FROM delivered_orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE delivery_outcome IS NOT NULL
GROUP BY delivery_outcome

-- Findings:

-- Worst sellers for late delivery: late rate and order count, with a minimum order threshold to reduce noise from smaller sellers

SELECT s.seller_id,
		COUNT(o.order_id) AS order_count,
		ROUND(COUNT(*) FILTER (WHERE o.is_late = 1) * 100.0 / COUNT(*), 2) AS late_rate
FROM delivered_orders o
JOIN order_items i ON o.order_id = i.order_id
JOIN sellers s ON i.seller_id = s.seller_id
GROUP BY s.seller_id
HAVING order_count > 30
ORDER BY late_rate DESC

-- Findings:


-- Repeat Purchases --
-- Repeat purchase rate
WITH customer_orders AS (
    SELECT
        customer_unique_id,
        COUNT(order_id) AS total_orders
    FROM delivered_orders
    GROUP BY customer_unique_id
)

SELECT
    ROUND(
        COUNT(*) FILTER (WHERE total_orders >= 2) * 100.0
        / COUNT(*), 2
    ) AS repeat_purchase_rate
FROM customer_orders;

-- Findings: 3.0% of the customers have made a repeat purchase

-- Orders per customer distribution
SELECT CASE
		    WHEN total_orders = 1 THEN '1 order'
			WHEN total_orders = 2 THEN '2 orders'
			WHEN total_orders= 3 THEN  '3 orders'
	        ELSE '4+ orders'
		END AS order_bins,
	COUNT(*) AS customer_count
FROM customer_orders
GROUP BY order_bins
ORDER BY total_orders ASC

-- Findings:

-- Late first order vs. repeat rate
WITH ranked_order AS (
	SELECT *, ROW_NUMBER() OVER (
		PARTITION BY customer_unique_id
		ORDER BY order_purchase_timestamp) AS order_rank
	FROM delivered_orders
)

SELECT COUNT(order_id) FILTER (WHERE order_rank = 1 AND is_late = 1) AS first_order_late,
	COUNT(order_id) FILTER (WHERE order_rank = 2) AS ordered_again
FROM ranked_order

-- Findings:


-- Window Fuctions --
-- Top 3 categories per state by revenue


-- Findings:

-- Customer spend quartiles


-- Findings:

-- Monthly cohorts


-- Findings: 