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