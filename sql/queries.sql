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
LIMIT 10;

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
DROP VIEW IF EXISTS monthly;
CREATE VIEW monthly AS
SELECT
	strftime('%Y-%m', o.order_purchase_timestamp) AS month,
    COUNT(DISTINCT o.order_id) AS dist_orders,
    ROUND(SUM(oi.price), 2) AS revenue,
    ROUND(
    	SUM(oi.price) * 1.0 / COUNT(DISTINCT o.order_id), 2
    ) AS avg_order_value
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
    AND o.order_purchase_timestamp >= '2017-01-01'
    AND o.order_purchase_timestamp < '2018-09-01'
GROUP BY month;

SELECT strftime('%Y-%m', o.order_purchase_timestamp) AS month, 
	COUNT(DISTINCT o.order_id) AS dist_orders,
	SUM(oi.price) AS revenue
	FROM orders o
	JOIN order_items oi ON o.order_id = oi.order_id
	WHERE o.order_status = 'delivered'
		AND o.order_purchase_timestamp >= '2017-01-01'
		AND o.order_purchase_timestamp <  '2018-09-01'
	GROUP BY month;

SELECT *
FROM monthly
ORDER BY avg_order_value DESC;

-- Findings: The month with the highest average order value is 2017-01 with an average order 
-- value of 149.06, but contained the least amount of orders and revenue.

-- Running total of revenue

SELECT
    month,
    ROUND(revenue, 2) AS revenue,
    ROUND(
        SUM(revenue) OVER (
            ORDER BY month
        ), 2
    ) AS running_total
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
ORDER BY total_value DESC;

-- Findings: The payment type with the highest orders and total value is 
-- credit_card with 74304 orders and 78.46% of the total revenue.

-- Advanced Queries --
-- Reuseable CTE that gives one row per delivered order

DROP VIEW IF EXISTS delivered_orders;
CREATE VIEW delivered_orders AS
SELECT
    o.order_id,
    c.customer_unique_id,
    c.customer_state,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    ROUND(julianday(o.order_delivered_customer_date)
        - julianday(o.order_purchase_timestamp), 1) AS delivery_days,
    CAST(julianday(date(o.order_delivered_customer_date))
        - julianday(date(o.order_estimated_delivery_date)) AS INTEGER) AS days_late,
    CASE WHEN date(o.order_delivered_customer_date) > date(o.order_estimated_delivery_date)
         THEN 1 ELSE 0 END AS is_late
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL;

SELECT COUNT(*) AS count, COUNT(order_delivered_customer_date) AS delivered_count
FROM delivered_orders;

-- Checked that number of rows = number of delivered orders (96476 = 96476)


-- Delivery performance and reviews --
-- Overall late delivery rate and average days late for late deliveries
SELECT COUNT(*) FILTER (WHERE is_late = 1) AS late_count,
		ROUND(
        COUNT(*) FILTER (WHERE is_late = 1) * 100.0/ COUNT(*), 2
		) AS late_delivery_rate,
		ROUND(AVG(days_late) FILTER (WHERE is_late = 1), 2) AS avg_days_late
FROM delivered_orders;

-- Findings: 6534 orders were delivered late, with a 6.77 late delivery rate and an average of 10.62 days late for late deliveries.

-- Late delivery rate by customer state, worst to best
SELECT customer_state,
    	COUNT(*) AS orders,
    	ROUND(100.0 * SUM(is_late) / COUNT(*), 2) AS late_delivery_rate
FROM delivered_orders
GROUP BY customer_state
ORDER BY late_delivery_rate DESC;

-- Findings: The state with the worst late delivery rate is AL with 21.41, and the best being AM with 2.76.
-- The late delivery rate seems to be steadily increasing when compared between states

-- Average review score by delivery bucket: early, on time, 1-3 days late, 4-7 days late, 8+ days late

DROP VIEW IF EXISTS order_scores;

CREATE VIEW order_scores AS
SELECT
    order_id,
    AVG(review_score) AS review_score
FROM order_reviews
GROUP BY order_id;

SELECT CASE 
			WHEN days_late < 0 THEN 'early'
			WHEN days_late = 0 THEN 'on time'
			WHEN days_late BETWEEN 1 AND 3 THEN '1-3 days late'
			WHEN days_late BETWEEN 4 AND 7 THEN '4-7 days late'
			ELSE '8+ days late'
		END AS delivery_bucket,
	ROUND(AVG(s.review_score), 2) AS avg_review
FROM delivered_orders o
JOIN order_scores s ON o.order_id = s.order_id
GROUP BY delivery_bucket
ORDER BY delivery_bucket;

-- Findings: The findings to this are not surprising at all, as the orders are more late the less stars it has. With earliest deliveries having the highest ratings.

-- Review score for late vs. on-time orders, with average score and the share of 1-star reviews for each
SELECT CASE 
		    WHEN days_late = 1 THEN 'late'
			ELSE 'on time'
        END AS delivery_outcome,
	COUNT(*) AS orders,
	ROUND(AVG(s.review_score), 2) AS avg_review,
	ROUND(100.0 * SUM(s.review_score <= 1.5) / COUNT(*), 2) AS pct_one_star
FROM delivered_orders o
JOIN order_scores s ON o.order_id = s.order_id
WHERE delivery_outcome IS NOT NULL
GROUP BY delivery_outcome;

-- Findings: Late deliveries tend to have a lower review with a higher one star rate,  but the ratio between
-- late and on time deliveries is big (820 late vs 96004 on time or earlier)

-- Worst sellers for late delivery: late rate and order count, with a minimum order threshold to reduce noise from smaller sellers

SELECT i.seller_id,
		COUNT(DISTINCT o.order_id) AS order_count,
		ROUND(COUNT(DISTINCT o.order_id) FILTER (WHERE o.is_late = 1) * 100.0 / COUNT(DISTINCT o.order_id), 2) AS late_rate
FROM delivered_orders o
JOIN order_items i ON o.order_id = i.order_id
GROUP BY i.seller_id
HAVING order_count > 30
ORDER BY late_rate DESC;

-- Findings: seller_id are encoded, but the highest late_rate is 32.56 out of 611 sellers


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
        COUNT(*) FILTER (WHERE total_orders >= 2) * 100.0 / COUNT(*), 2
    ) AS repeat_purchase_rate
FROM customer_orders;

-- Findings: 3.0% of the customers have made a repeat purchase

-- Orders per customer distribution
WITH customer_orders AS (
    SELECT customer_unique_id, COUNT(*) AS total_orders
    FROM delivered_orders
    GROUP BY customer_unique_id
)

SELECT CASE
		    WHEN total_orders = 1 THEN '1 order'
			WHEN total_orders = 2 THEN '2 orders'
			WHEN total_orders= 3 THEN  '3 orders'
	        ELSE '4+ orders'
		END AS order_bins,
	COUNT(*) AS customer_count
FROM customer_orders
GROUP BY order_bins
ORDER BY MIN(total_orders);

-- Findings: Customers who ordered once had the highest count with 90549 customers and those who ordered 4+ times had a count of 47 customers

-- Late first order vs. repeat rate
WITH ranked AS (
	SELECT customer_unique_id, is_late,
        	ROW_NUMBER() OVER (PARTITION BY customer_unique_id
                            ORDER BY order_purchase_timestamp) AS rn,
           	COUNT(*) OVER (PARTITION BY customer_unique_id) AS total_orders
    FROM delivered_orders
)
SELECT CASE WHEN is_late = 1 THEN 'first order late' 
			ELSE 'first order on time/early' END AS first_order,
       COUNT(*) AS customers,
       SUM(total_orders >= 2) AS repeat_customers,
       ROUND(100.0 * SUM(total_orders >= 2) / COUNT(*), 2) AS repeat_rate
FROM ranked
WHERE rn = 1
GROUP BY is_late;

-- Findings: The ratio between first orders being late and on time is big (86993 on time or early vs 6357 late)
-- Both categories had similar repeat order rates (3.03 vs 2.55). This is because of the small amount of customers who
-- ordered again based on their category.


-- Window Fuctions --
-- Top 3 categories per state by revenue
WITH category_revenue AS (
    SELECT
        c.customer_state,
        COALESCE(pc.product_category_name_english, p.product_category_name, 'unknown') AS category,
        SUM(oi.price) AS total_revenue
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
	LEFT JOIN product_category_name_translation pc ON p.product_category_name = pc.product_category_name
    WHERE o.order_status = 'delivered'
    GROUP BY
        c.customer_state,
        pc.product_category_name_english
),

ranked_categories AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_state
            ORDER BY total_revenue DESC
        ) AS category_rank
    FROM category_revenue
)

SELECT *
FROM ranked_categories
WHERE category_rank <= 3
ORDER BY customer_state, category_rank;

-- Findings: From the query output, the most repeated category is health_beauty. With it being the top revenue provider in some states,
-- or in the top three.

-- Customer spend quartiles
WITH customer_spendings AS (
		SELECT c.customer_unique_id, 
				ROUND(SUM(oi.price), 2) AS total_revenue
		FROM orders o
		JOIN customers c ON o.customer_id = c.customer_id
		JOIN order_items oi ON o.order_id = oi.order_id
		WHERE o.order_status = 'delivered'
		GROUP BY c.customer_unique_id
),

quartiles AS (
	SELECT *,
			NTILE(4) OVER (
					ORDER BY total_revenue
			) AS quartile
	FROM customer_spendings
)

SELECT quartile, 
		COUNT(*) AS customer_count,
		ROUND(SUM(total_revenue), 2) AS quartile_revenue,
		ROUND(AVG(total_revenue), 2) AS avg_customer_spending
FROM quartiles
GROUP BY quartile
ORDER BY quartile;

-- Findings: Quartile 4 has the most revenue ($8267262.49) along with the highest average customer spending of $354.23 per customer

-- Monthly cohorts
WITH ranked_orders AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_unique_id
            ORDER BY order_purchase_timestamp, order_id
        ) AS order_rank
    FROM delivered_orders
),

first_purchase_month AS (
	SELECT customer_unique_id,
			order_purchase_timestamp AS first_purchase_date,
			strftime('%Y-%m', order_purchase_timestamp) AS cohort_month
	FROM ranked_orders
	WHERE order_rank = 1
),

returning_custs AS (
    SELECT DISTINCT f.customer_unique_id
    FROM first_purchase_month f
    JOIN ranked_orders r
    	ON r.customer_unique_id = f.customer_unique_id
    	AND r.order_rank > 1
    	AND julianday(r.order_purchase_timestamp) - julianday(f.first_purchase_date) <= 90
)

SELECT fpm.cohort_month,
    	COUNT(*) AS cohort_size,
    	COUNT(rc.customer_unique_id) AS returning_customers,
    	ROUND(COUNT(rc.customer_unique_id) * 100.0 / COUNT(*), 2) AS return_rate
FROM first_purchase_month fpm
LEFT JOIN returning_custs rc
    	ON fpm.customer_unique_id = rc.customer_unique_id
WHERE fpm.cohort_month BETWEEN '2017-01' AND '2018-05'
GROUP BY fpm.cohort_month
ORDER BY fpm.cohort_month;

-- Findings: The month with the highest number of returning customers was 2018-02 (6288 customers) with a return rate of  2.99%.
-- The lowest number of returning customers was 2017-01 (717 customers) wih a return rate of 3.63%