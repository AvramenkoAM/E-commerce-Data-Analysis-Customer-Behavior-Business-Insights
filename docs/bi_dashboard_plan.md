# BI Dashboard Plan: Tableau / Power BI

## Goal

Build a portfolio-ready BI dashboard that turns the Olist e-commerce analysis into an interactive business intelligence product. The dashboard should show revenue, customer behavior, payment mix, review quality, delivery performance, seller risk, category performance, and regional opportunities.

## Recommended Tool Choice

Start with Power BI if the goal is business analyst / BI analyst positioning, because it highlights data modeling, DAX measures, slicers, and stakeholder dashboards.

Use Tableau if the goal is stronger visual storytelling and public portfolio sharing through Tableau Public.

Best portfolio path:

1. Build the cleaned analytical dataset once.
2. Create the first full dashboard in Power BI.
3. Optionally recreate a lighter storytelling version in Tableau Public.

## Dashboard Pages

### 1. Executive Overview

Purpose: give a recruiter or stakeholder the answer in the first 30 seconds.

Recommended visuals:

- KPI cards: total orders, GMV, AOV, unique customers, repeat purchase rate, average review score, late delivery rate, cancellation rate.
- Monthly GMV and order volume trend.
- Revenue by payment method.
- Top product categories by GMV.
- Short insight text box with the main business takeaway.

### 2. Sales and Customer Behavior

Purpose: explain growth, seasonality, and retention.

Recommended visuals:

- Monthly order volume.
- Monthly GMV and AOV.
- Orders per customer distribution.
- Repeat vs one-time customers.
- Customer state map or bar chart.
- Customer cohort or repeat-purchase summary if time allows.

### 3. Payments and Revenue Mix

Purpose: show monetization patterns and payment-method dependency.

Recommended visuals:

- Payment method share.
- Revenue by payment method.
- AOV by payment method.
- Installments distribution.
- Payment method by month.

### 4. Reviews and Customer Satisfaction

Purpose: connect customer experience with operational quality.

Recommended visuals:

- Average review score over time.
- Review score distribution.
- Negative review rate by category.
- Average delivery days by review score.
- Worst categories by average review score.

### 5. Logistics and Delivery Risk

Purpose: show delivery delays as an operational risk.

Recommended visuals:

- Average delivery days.
- Late delivery rate.
- Late delivery rate by customer state.
- Delivery days by product category.
- Distance proxy vs delivery time.
- On-time vs delayed order split.

### 6. Seller and Category Risk

Purpose: identify where marketplace quality control should focus.

Recommended visuals:

- Top sellers by order volume.
- Sellers with highest negative-review rate.
- Sellers linked to cancellations.
- Categories with longest delivery time.
- Composite risk score by category.

### 7. Geographic Opportunity

Purpose: show demand and supply gaps by region.

Recommended visuals:

- Customers by state.
- Sellers by state.
- Customer-to-seller ratio by state.
- AOV by state.
- Late delivery rate by state.

## Analytical Dataset Design

Create a `bi_exports/` folder with CSV files generated from the existing Excel data.

Recommended exports:

- `orders_enriched.csv`: one row per order with customer, order status, purchase month, delivery days, late-delivery flag, payment total, review score, and state.
- `order_items_enriched.csv`: one row per order item with product category English name, seller state, item revenue, price, freight, and order status.
- `category_metrics.csv`: one row per category with orders, GMV, AOV, average review score, negative review rate, average delivery days, late delivery rate, and cancellation rate.
- `seller_metrics.csv`: one row per seller with orders, GMV, average review score, negative review rate, cancellation rate, and seller state.
- `state_metrics.csv`: one row per customer state with customers, orders, sellers, GMV, AOV, late delivery rate, and average review score.
- `monthly_metrics.csv`: one row per month with orders, GMV, AOV, customers, average review score, late delivery rate, and cancellation rate.

## Data Model

Recommended star-schema style:

- Fact table: orders or order_items, depending on page.
- Dimensions: date, customer state, seller, product category, payment method.
- Aggregated helper tables: category metrics, seller metrics, state metrics, monthly metrics.

Power BI measures to create:

- `GMV = SUM(order_items_enriched[item_revenue])`
- `Orders = DISTINCTCOUNT(orders_enriched[order_id])`
- `Customers = DISTINCTCOUNT(orders_enriched[customer_unique_id])`
- `AOV = DIVIDE([GMV], [Orders])`
- `Late Delivery Rate = DIVIDE([Late Orders], [Delivered Orders])`
- `Negative Review Rate = DIVIDE([Negative Reviews], [Reviews])`
- `Cancellation Rate = DIVIDE([Canceled Orders], [Orders])`
- `Repeat Purchase Rate = DIVIDE([Repeat Customers], [Customers])`

## Portfolio Presentation

Add the final BI work to the repository:

- `bi_exports/`: exported CSVs used by Tableau or Power BI.
- `dashboards/`: `.pbix`, `.twbx`, screenshots, or exported PDF.
- `images/bi/`: dashboard screenshots for README preview.
- README section: dashboard objective, screenshots, key insights, and tool used.

Recommended final screenshots:

1. Executive Overview.
2. Logistics Risk.
3. Seller and Category Risk.
4. Geographic Opportunity.

## Implementation Steps

1. Create a Python export script that builds clean CSVs in `bi_exports/`.
2. Validate row counts and key metrics against README snapshot.
3. Build the Power BI data model and core DAX measures.
4. Design the Executive Overview page first.
5. Add operational pages for reviews, logistics, sellers, categories, and geography.
6. Export dashboard screenshots to `images/bi/`.
7. Update README with dashboard screenshots and project story.
8. Commit and push the BI branch.

## Acceptance Criteria

- Dashboard can be opened and understood without reading the notebooks first.
- All top-level KPIs match the README snapshot or documented metric definitions.
- Every page answers a business question, not only a charting question.
- The dashboard includes filters for month, customer state, product category, and payment method.
- README includes screenshots and a short BI-focused project explanation.
