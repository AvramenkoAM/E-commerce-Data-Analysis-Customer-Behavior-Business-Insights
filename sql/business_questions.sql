-- E-commerce Data Analysis: Customer Behavior & Business Insights
-- Reviewed SQLite query set for the Olist Brazilian e-commerce dataset.
-- Tables are expected to be cleaned and loaded with the same names as the files:
-- customers, geolocation, order_items, order_payments, order_reviews,
-- orders, products, sellers, category_translation.

-- 1. Total orders
SELECT COUNT(DISTINCT order_id) AS total_orders
FROM orders;

-- 2. Unique customers
SELECT COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM customers;

-- 3. Sellers on the platform
SELECT COUNT(DISTINCT seller_id) AS sellers_count
FROM sellers;

-- 4. Unique products sold
SELECT COUNT(DISTINCT product_id) AS unique_products_sold
FROM order_items;

-- 5. Average order value
WITH order_totals AS (
    SELECT order_id, SUM(payment_value) AS order_total
    FROM order_payments
    GROUP BY order_id
)
SELECT ROUND(AVG(order_total), 2) AS avg_order_value
FROM order_totals;

-- 6. Monthly orders
SELECT
    strftime('%Y-%m', order_purchase_timestamp) AS order_month,
    COUNT(DISTINCT order_id) AS orders_count
FROM orders
GROUP BY order_month
ORDER BY order_month;

-- 7. Seasonality by calendar month
WITH monthly_orders AS (
    SELECT
        strftime('%Y-%m', order_purchase_timestamp) AS year_month,
        strftime('%m', order_purchase_timestamp) AS calendar_month,
        COUNT(DISTINCT order_id) AS orders_count
    FROM orders
    GROUP BY year_month, calendar_month
    HAVING COUNT(DISTINCT order_id) > 1000
)
SELECT
    calendar_month,
    ROUND(AVG(orders_count), 2) AS avg_orders
FROM monthly_orders
GROUP BY calendar_month
ORDER BY calendar_month;

-- 8. Best month by average order volume
WITH monthly_orders AS (
    SELECT
        strftime('%Y-%m', order_purchase_timestamp) AS year_month,
        strftime('%m', order_purchase_timestamp) AS calendar_month,
        COUNT(DISTINCT order_id) AS orders_count
    FROM orders
    GROUP BY year_month, calendar_month
    HAVING COUNT(DISTINCT order_id) > 1000
)
SELECT
    calendar_month,
    ROUND(AVG(orders_count), 2) AS avg_orders
FROM monthly_orders
GROUP BY calendar_month
ORDER BY avg_orders DESC
LIMIT 1;

-- 9. GMV over time
SELECT
    strftime('%Y-%m', o.order_purchase_timestamp) AS order_month,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS gmv
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY order_month
ORDER BY order_month;

-- 10. Average orders per customer
WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS orders_count
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)
SELECT ROUND(AVG(orders_count), 2) AS avg_orders_per_customer
FROM customer_orders;

-- 11. Repeat purchase rate
WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS orders_count
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    ROUND(100.0 * SUM(CASE WHEN orders_count > 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS repeat_purchase_rate_pct
FROM customer_orders;

-- 12. Average days between repeat orders
WITH ordered_purchases AS (
    SELECT
        c.customer_unique_id,
        o.order_purchase_timestamp,
        LAG(o.order_purchase_timestamp) OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp
        ) AS previous_purchase_timestamp
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
)
SELECT
    ROUND(AVG(julianday(order_purchase_timestamp) - julianday(previous_purchase_timestamp)), 2) AS avg_days_between_orders
FROM ordered_purchases
WHERE previous_purchase_timestamp IS NOT NULL;

-- 13. Average customer lifetime value
WITH customer_revenue AS (
    SELECT
        c.customer_unique_id,
        SUM(oi.price + oi.freight_value) AS revenue
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
)
SELECT ROUND(AVG(revenue), 2) AS avg_clv
FROM customer_revenue;

-- 14. Payment method popularity
SELECT
    payment_type,
    COUNT(*) AS payments_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS share_pct
FROM order_payments
GROUP BY payment_type
ORDER BY payments_count DESC;

-- 15. Average order value by payment method
WITH payment_order_totals AS (
    SELECT
        order_id,
        payment_type,
        SUM(payment_value) AS order_total
    FROM order_payments
    GROUP BY order_id, payment_type
)
SELECT
    payment_type,
    ROUND(AVG(order_total), 2) AS avg_order_value
FROM payment_order_totals
GROUP BY payment_type
ORDER BY avg_order_value DESC;

-- 16. Revenue by payment method
WITH payment_order_totals AS (
    SELECT
        order_id,
        payment_type,
        SUM(payment_value) AS order_total
    FROM order_payments
    GROUP BY order_id, payment_type
)
SELECT
    payment_type,
    ROUND(SUM(order_total), 2) AS revenue
FROM payment_order_totals
GROUP BY payment_type
ORDER BY revenue DESC;

-- 17. Average review score
SELECT ROUND(AVG(review_score), 2) AS avg_review_score
FROM order_reviews;

-- 18. Negative review share
SELECT
    ROUND(100.0 * SUM(CASE WHEN review_score IN (1, 2) THEN 1 ELSE 0 END) / COUNT(*), 2) AS negative_review_rate_pct
FROM order_reviews;

-- 19. Delivery time by review score
SELECT
    r.review_score,
    ROUND(AVG(julianday(o.order_delivered_customer_date) - julianday(o.order_purchase_timestamp)), 2) AS avg_delivery_days
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY r.review_score
ORDER BY r.review_score;

-- 20. Worst reviewed product categories
SELECT
    ct.product_category_name_english AS category,
    COUNT(DISTINCT r.review_id) AS reviews_count,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
JOIN order_reviews r ON oi.order_id = r.order_id
JOIN category_translation ct ON p.product_category_name = ct.product_category_name
GROUP BY category
HAVING reviews_count >= 50
ORDER BY avg_review_score ASC, reviews_count DESC
LIMIT 20;

-- 21. Average delivery duration
SELECT
    ROUND(AVG(julianday(order_delivered_customer_date) - julianday(order_purchase_timestamp)), 2) AS avg_delivery_days
FROM orders
WHERE order_delivered_customer_date IS NOT NULL;

-- 22. Late delivery share
SELECT
    ROUND(100.0 * SUM(CASE WHEN julianday(order_delivered_customer_date) > julianday(order_estimated_delivery_date) THEN 1 ELSE 0 END) / COUNT(*), 2) AS delayed_rate_pct
FROM orders
WHERE order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;

-- 23. States with the largest late-delivery risk
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    SUM(CASE WHEN julianday(o.order_delivered_customer_date) > julianday(o.order_estimated_delivery_date) THEN 1 ELSE 0 END) AS delayed_orders,
    ROUND(100.0 * SUM(CASE WHEN julianday(o.order_delivered_customer_date) > julianday(o.order_estimated_delivery_date) THEN 1 ELSE 0 END) / COUNT(DISTINCT o.order_id), 2) AS delayed_rate_pct,
    ROUND(AVG(CASE WHEN julianday(o.order_delivered_customer_date) > julianday(o.order_estimated_delivery_date)
        THEN julianday(o.order_delivered_customer_date) - julianday(o.order_estimated_delivery_date) END), 2) AS avg_delay_days_late_only
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY c.customer_state
HAVING delivered_orders >= 100
ORDER BY delayed_rate_pct DESC, avg_delay_days_late_only DESC;

-- 24. Delay impact on rating
SELECT
    CASE
        WHEN julianday(o.order_delivered_customer_date) > julianday(o.order_estimated_delivery_date) THEN 'delayed'
        ELSE 'on_time_or_early'
    END AS delivery_status,
    COUNT(DISTINCT r.review_id) AS reviews_count,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY delivery_status;

-- 25. Average orders per seller
WITH seller_orders AS (
    SELECT
        seller_id,
        COUNT(DISTINCT order_id) AS orders_count,
        COUNT(*) AS items_count
    FROM order_items
    GROUP BY seller_id
)
SELECT
    ROUND(AVG(orders_count), 2) AS avg_orders_per_seller,
    ROUND(AVG(items_count), 2) AS avg_items_per_seller
FROM seller_orders;

-- 26. Top sellers by order count
SELECT
    seller_id,
    COUNT(DISTINCT order_id) AS orders_count,
    COUNT(*) AS items_count
FROM order_items
GROUP BY seller_id
ORDER BY orders_count DESC
LIMIT 10;

-- 27. Seller rating spread
WITH seller_reviews AS (
    SELECT
        oi.seller_id,
        COUNT(DISTINCT oi.order_id) AS orders_count,
        COUNT(DISTINCT r.review_id) AS reviews_count,
        AVG(r.review_score) AS avg_review_score
    FROM order_items oi
    JOIN order_reviews r ON oi.order_id = r.order_id
    GROUP BY oi.seller_id
    HAVING COUNT(DISTINCT oi.order_id) >= 50
)
SELECT
    ROUND(MIN(avg_review_score), 2) AS min_seller_avg_score,
    ROUND(MAX(avg_review_score), 2) AS max_seller_avg_score,
    ROUND(MAX(avg_review_score) - MIN(avg_review_score), 2) AS score_spread
FROM seller_reviews;

-- 28. Sellers with the highest negative review rate
SELECT
    oi.seller_id,
    COUNT(DISTINCT r.review_id) AS total_reviews,
    COUNT(DISTINCT CASE WHEN r.review_score IN (1, 2) THEN r.review_id END) AS negative_reviews,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN r.review_score IN (1, 2) THEN r.review_id END) / COUNT(DISTINCT r.review_id), 2) AS negative_review_rate_pct
FROM order_items oi
JOIN order_reviews r ON oi.order_id = r.order_id
GROUP BY oi.seller_id
HAVING COUNT(DISTINCT oi.order_id) >= 50
ORDER BY negative_review_rate_pct DESC, total_reviews DESC
LIMIT 20;

-- 29. Best-selling categories
SELECT
    ct.product_category_name_english AS category,
    COUNT(DISTINCT oi.order_id) AS orders_count,
    COUNT(*) AS items_count
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
JOIN category_translation ct ON p.product_category_name = ct.product_category_name
GROUP BY category
ORDER BY orders_count DESC
LIMIT 20;

-- 30. Top revenue categories
SELECT
    ct.product_category_name_english AS category,
    COUNT(DISTINCT oi.order_id) AS orders_count,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS revenue,
    ROUND(AVG(oi.price), 2) AS avg_item_price
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
JOIN category_translation ct ON p.product_category_name = ct.product_category_name
GROUP BY category
ORDER BY revenue DESC
LIMIT 20;

-- 31. Categories with the highest negative review rate
SELECT
    ct.product_category_name_english AS category,
    COUNT(DISTINCT r.review_id) AS reviews_count,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    COUNT(DISTINCT CASE WHEN r.review_score IN (1, 2) THEN r.review_id END) AS negative_reviews,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN r.review_score IN (1, 2) THEN r.review_id END) / COUNT(DISTINCT r.review_id), 2) AS negative_review_rate_pct
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
JOIN category_translation ct ON p.product_category_name = ct.product_category_name
JOIN order_reviews r ON oi.order_id = r.order_id
GROUP BY category
HAVING reviews_count >= 50
ORDER BY negative_review_rate_pct DESC, reviews_count DESC
LIMIT 20;

-- 32. Categories with the longest delivery time
SELECT
    ct.product_category_name_english AS category,
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    ROUND(AVG(julianday(o.order_delivered_customer_date) - julianday(o.order_purchase_timestamp)), 2) AS avg_delivery_days
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
JOIN category_translation ct ON p.product_category_name = ct.product_category_name
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY category
HAVING delivered_orders >= 50
ORDER BY avg_delivery_days DESC
LIMIT 20;

-- 33. States with the most customers
SELECT
    customer_state,
    COUNT(DISTINCT customer_unique_id) AS customers_count
FROM customers
GROUP BY customer_state
ORDER BY customers_count DESC
LIMIT 10;

-- 34. States with the most sellers
SELECT
    seller_state,
    COUNT(DISTINCT seller_id) AS sellers_count
FROM sellers
GROUP BY seller_state
ORDER BY sellers_count DESC
LIMIT 10;

-- 35. Average order value by customer state
WITH order_totals AS (
    SELECT
        o.order_id,
        o.customer_id,
        SUM(oi.price + oi.freight_value) AS order_total
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY o.order_id, o.customer_id
)
SELECT
    c.customer_state,
    COUNT(DISTINCT t.order_id) AS orders_count,
    ROUND(AVG(t.order_total), 2) AS avg_order_value
FROM order_totals t
JOIN customers c ON t.customer_id = c.customer_id
GROUP BY c.customer_state
HAVING orders_count >= 100
ORDER BY avg_order_value DESC;

-- 36. Distance proxy and delivery time
WITH geo AS (
    SELECT
        geolocation_zip_code_prefix,
        AVG(geolocation_lat) AS lat,
        AVG(geolocation_lng) AS lng
    FROM geolocation
    GROUP BY geolocation_zip_code_prefix
), order_distance AS (
    SELECT
        o.order_id,
        ABS(gc.lat - gs.lat) + ABS(gc.lng - gs.lng) AS distance_proxy,
        julianday(o.order_delivered_customer_date) - julianday(o.order_purchase_timestamp) AS delivery_days
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN sellers s ON oi.seller_id = s.seller_id
    JOIN geo gc ON c.customer_zip_code_prefix = gc.geolocation_zip_code_prefix
    JOIN geo gs ON s.seller_zip_code_prefix = gs.geolocation_zip_code_prefix
    WHERE o.order_delivered_customer_date IS NOT NULL
)
SELECT
    CASE
        WHEN distance_proxy < 1 THEN 'near'
        WHEN distance_proxy < 5 THEN 'medium'
        ELSE 'far'
    END AS distance_group,
    COUNT(DISTINCT order_id) AS orders_count,
    ROUND(AVG(delivery_days), 2) AS avg_delivery_days
FROM order_distance
GROUP BY distance_group
ORDER BY avg_delivery_days;

-- 37. Cancellation rate
SELECT
    COUNT(*) AS total_orders,
    SUM(CASE WHEN order_status = 'canceled' THEN 1 ELSE 0 END) AS canceled_orders,
    ROUND(100.0 * SUM(CASE WHEN order_status = 'canceled' THEN 1 ELSE 0 END) / COUNT(*), 2) AS canceled_rate_pct
FROM orders;

-- 38. Sellers linked to cancellations
SELECT
    oi.seller_id,
    COUNT(DISTINCT o.order_id) AS orders_count,
    COUNT(DISTINCT CASE WHEN o.order_status = 'canceled' THEN o.order_id END) AS canceled_orders,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN o.order_status = 'canceled' THEN o.order_id END) / COUNT(DISTINCT o.order_id), 2) AS canceled_rate_pct
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
GROUP BY oi.seller_id
HAVING orders_count >= 50
ORDER BY canceled_rate_pct DESC, canceled_orders DESC
LIMIT 20;

-- 39. Estimated delivery window and cancellation rate
SELECT
    CASE
        WHEN julianday(order_estimated_delivery_date) - julianday(order_purchase_timestamp) > 14 THEN 'long_estimated_delivery'
        ELSE 'short_estimated_delivery'
    END AS delivery_window,
    COUNT(*) AS orders_count,
    SUM(CASE WHEN order_status = 'canceled' THEN 1 ELSE 0 END) AS canceled_orders,
    ROUND(100.0 * SUM(CASE WHEN order_status = 'canceled' THEN 1 ELSE 0 END) / COUNT(*), 2) AS canceled_rate_pct
FROM orders
WHERE order_purchase_timestamp IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
GROUP BY delivery_window;

-- 40. Product categories with the highest composite risk
WITH category_base AS (
    SELECT
        ct.product_category_name_english AS category,
        oi.order_id
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    JOIN category_translation ct ON p.product_category_name = ct.product_category_name
), category_risk AS (
    SELECT
        cb.category,
        COUNT(DISTINCT cb.order_id) AS orders_count,
        COUNT(DISTINCT CASE WHEN o.order_status = 'canceled' THEN cb.order_id END) AS canceled_orders,
        COUNT(DISTINCT r.review_id) AS reviews_count,
        COUNT(DISTINCT CASE WHEN r.review_score IN (1, 2) THEN r.review_id END) AS negative_reviews,
        COUNT(DISTINCT CASE WHEN julianday(o.order_delivered_customer_date) > julianday(o.order_estimated_delivery_date) THEN cb.order_id END) AS delayed_orders
    FROM category_base cb
    JOIN orders o ON cb.order_id = o.order_id
    LEFT JOIN order_reviews r ON cb.order_id = r.order_id
    GROUP BY cb.category
)
SELECT
    category,
    orders_count,
    ROUND(100.0 * canceled_orders / orders_count, 2) AS canceled_rate_pct,
    ROUND(100.0 * negative_reviews / NULLIF(reviews_count, 0), 2) AS negative_review_rate_pct,
    ROUND(100.0 * delayed_orders / orders_count, 2) AS delayed_rate_pct
FROM category_risk
WHERE orders_count >= 50
ORDER BY
    (100.0 * canceled_orders / orders_count)
    + (100.0 * negative_reviews / NULLIF(reviews_count, 0))
    + (100.0 * delayed_orders / orders_count) DESC
LIMIT 20;
