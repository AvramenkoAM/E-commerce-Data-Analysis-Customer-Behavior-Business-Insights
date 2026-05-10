# Data

This folder contains Excel exports of the Olist Brazilian E-commerce Public Dataset.

The dataset is used for educational and portfolio analysis only. Original source: Kaggle, "Brazilian E-Commerce Public Dataset by Olist".

## Tables

- `olist_orders_dataset.xlsx`: order status and timestamps.
- `olist_customers_dataset.xlsx`: customer location and unique customer IDs.
- `olist_order_items_dataset.xlsx`: item-level order, seller, product, price, and freight data.
- `olist_order_payments_dataset.xlsx`: payment method and payment value rows.
- `olist_order_reviews_dataset.xlsx`: customer review scores and review text fields.
- `olist_products_dataset.xlsx`: product category and product attributes.
- `olist_sellers_dataset.xlsx`: seller location data.
- `olist_geolocation_dataset.xlsx`: zip prefix geolocation reference.
- `product_category_name_translation.xlsx`: product category English translation.

## Notes

- One order can have multiple item rows.
- One order can have multiple payment rows, so payment values should be aggregated to order level before calculating AOV.
- `customer_id` identifies an order-level customer record, while `customer_unique_id` identifies the same customer across orders.
- Geolocation contains multiple records for the same zip prefix. Aggregate coordinates by zip prefix before distance joins.
- Some monetary columns in these Excel exports may be auto-formatted as dates. The notebooks convert those cells back to numeric values before analysis.
