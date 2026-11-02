-- Queries are ran through DB Browser

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