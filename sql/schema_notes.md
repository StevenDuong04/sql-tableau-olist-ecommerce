## Understanding the schema
| Table | Primary Key | Foreign keys points to |
| :--- | :---: | ---: |
| customers | customer_id | customer_zip_code_prefix -> geolocation |
| orders | order_id | customer_id -> customers|
| order_items | order_id + order_item_id | order_id -> orders, product_id -> products, seller_id -> sellers |
| order_payments | order_id + payment_sequential | order_id -> orders |
| order_reviews | review_id | order_id -> orders |
| products | product_id | none |
| sellers | seller_id | seller_zip_code_prefix -> geolocation |
| geolocation | none | none |

## Data Quality Notes
- 97% of orders are delivered; revenue analysis filters to delivered only.
- Data spans Sept 2016 to Oct 2018; months with very few orders excluded from trends.
- 2965 delivered orders have a null delivery date; excluded from late-delivery analysis.
- Orders can have multiple payments and reviews; revenue uses order_items.price to avoid double counting.
- Repeat purchase analysis uses customer_unique_id, not customer_id.

# Join Paths
- orders -> customers: orders.customer_id = customers.customer_id
- orders -> order_items: orders.order_id = order_items.order_id
- order_items -> products: order_items.product_id = products.product_id
- products -> category translation: products.product_category_name = product_category_name_translation.product_category_name
- order_items -> sellers: order_items.seller_id = sellers.seller_id
- orders -> order_payments: orders.order_id = order_payments.order_id
- orders -> order_reviews: orders.order_id = order_reviews.order_id

## Decisions
- Revenue = SUM(order_items.price), not payment_value, to avoid double counting from multiple payment rows.
- Analysis window is 2017-01 to 2018-08; other months have too few orders and distort trends.
- Repeat purchase analysis uses customer_unique_id.
- Always use COUNT(DISTINCT order_id) after joining to order_items.