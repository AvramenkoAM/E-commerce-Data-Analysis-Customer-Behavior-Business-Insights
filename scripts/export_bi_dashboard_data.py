from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path

import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = PROJECT_ROOT / "data"
EXPORT_DIR = PROJECT_ROOT / "bi_exports"
EXPORT_DIR.mkdir(exist_ok=True)


def excel_date_number_to_float(value):
    if isinstance(value, datetime):
        if value.year == 2026:
            return value.day + value.month / 100
        return (value.year - 2000) + value.month / 100
    return value


def pct_change(current: float, previous: float) -> float:
    if previous == 0 or pd.isna(previous):
        return 0.0
    return (current - previous) / previous


def records(df: pd.DataFrame) -> list[dict]:
    return json.loads(df.to_json(orient="records"))


paths = {
    "customers": DATA_DIR / "olist_customers_dataset.xlsx",
    "order_items": DATA_DIR / "olist_order_items_dataset.xlsx",
    "order_payments": DATA_DIR / "olist_order_payments_dataset.xlsx",
    "order_reviews": DATA_DIR / "olist_order_reviews_dataset.xlsx",
    "orders": DATA_DIR / "olist_orders_dataset.xlsx",
    "products": DATA_DIR / "olist_products_dataset.xlsx",
    "sellers": DATA_DIR / "olist_sellers_dataset.xlsx",
    "category_translation": DATA_DIR / "product_category_name_translation.xlsx",
}

dataframes = {name: pd.read_excel(path) for name, path in paths.items()}

for table_name, columns in {
    "order_items": ["price", "freight_value"],
    "order_payments": ["payment_value"],
}.items():
    for column in columns:
        dataframes[table_name][column] = (
            dataframes[table_name][column]
            .map(excel_date_number_to_float)
            .pipe(pd.to_numeric, errors="coerce")
        )

customers = dataframes["customers"]
order_items = dataframes["order_items"]
order_payments = dataframes["order_payments"]
order_reviews = dataframes["order_reviews"]
orders = dataframes["orders"]
products = dataframes["products"]
sellers = dataframes["sellers"]
category_translation = dataframes["category_translation"]

orders["order_purchase_timestamp"] = pd.to_datetime(
    orders["order_purchase_timestamp"], errors="coerce"
)
orders["order_delivered_customer_date"] = pd.to_datetime(
    orders["order_delivered_customer_date"], errors="coerce"
)
orders["order_estimated_delivery_date"] = pd.to_datetime(
    orders["order_estimated_delivery_date"], errors="coerce"
)
orders["order_month"] = orders["order_purchase_timestamp"].dt.to_period("M").astype(str)

reviews_by_order = (
    order_reviews.groupby("order_id", as_index=False)
    .agg(review_score=("review_score", "mean"), reviews_count=("review_id", "nunique"))
)

payments_by_order = (
    order_payments.groupby("order_id", as_index=False)
    .agg(payment_total=("payment_value", "sum"))
)

payment_type_by_order = (
    order_payments.sort_values(["order_id", "payment_value"], ascending=[True, False])
    .drop_duplicates("order_id")[["order_id", "payment_type"]]
)

order_totals = (
    order_items.assign(item_revenue=order_items["price"] + order_items["freight_value"])
    .groupby("order_id", as_index=False)
    .agg(gmv=("item_revenue", "sum"), items_count=("product_id", "count"))
)

orders_enriched = (
    orders.merge(
        customers[
            [
                "customer_id",
                "customer_unique_id",
                "customer_city",
                "customer_state",
            ]
        ],
        on="customer_id",
        how="left",
    )
    .merge(order_totals, on="order_id", how="left")
    .merge(payments_by_order, on="order_id", how="left")
    .merge(payment_type_by_order, on="order_id", how="left")
    .merge(reviews_by_order, on="order_id", how="left")
)

orders_enriched["delivery_days"] = (
    orders_enriched["order_delivered_customer_date"]
    - orders_enriched["order_purchase_timestamp"]
).dt.days
orders_enriched["delay_days"] = (
    orders_enriched["order_delivered_customer_date"]
    - orders_enriched["order_estimated_delivery_date"]
).dt.days
orders_enriched["is_late"] = orders_enriched["delay_days"] > 0
orders_enriched["is_canceled"] = (
    orders_enriched["order_status"].astype(str).str.lower() == "canceled"
)
orders_enriched["is_negative_review"] = orders_enriched["review_score"].isin([1, 2])

product_categories = products.merge(
    category_translation, on="product_category_name", how="left"
)

order_items_enriched = (
    order_items.assign(item_revenue=order_items["price"] + order_items["freight_value"])
    .merge(
        product_categories[
            ["product_id", "product_category_name", "product_category_name_english"]
        ],
        on="product_id",
        how="left",
    )
    .merge(sellers[["seller_id", "seller_state"]], on="seller_id", how="left")
    .merge(
        orders_enriched[
            [
                "order_id",
                "order_status",
                "order_month",
                "customer_unique_id",
                "customer_state",
                "delivery_days",
                "is_late",
                "is_canceled",
                "review_score",
                "is_negative_review",
            ]
        ],
        on="order_id",
        how="left",
    )
)

category_metrics = (
    order_items_enriched.dropna(subset=["product_category_name_english"])
    .groupby("product_category_name_english", as_index=False)
    .agg(
        orders=("order_id", "nunique"),
        gmv=("item_revenue", "sum"),
        aov=("item_revenue", "mean"),
        avg_review_score=("review_score", "mean"),
        negative_reviews=("is_negative_review", "sum"),
        reviews=("review_score", "count"),
        avg_delivery_days=("delivery_days", "mean"),
        late_orders=("is_late", "sum"),
        canceled_orders=("is_canceled", "sum"),
    )
    .rename(columns={"product_category_name_english": "category"})
)
category_metrics["negative_review_rate"] = (
    category_metrics["negative_reviews"] / category_metrics["reviews"].replace(0, pd.NA)
)
category_metrics["late_delivery_rate"] = (
    category_metrics["late_orders"] / category_metrics["orders"].replace(0, pd.NA)
)
category_metrics["cancellation_rate"] = (
    category_metrics["canceled_orders"] / category_metrics["orders"].replace(0, pd.NA)
)
category_metrics["risk_score"] = (
    category_metrics["negative_review_rate"].fillna(0)
    + category_metrics["late_delivery_rate"].fillna(0)
    + category_metrics["cancellation_rate"].fillna(0)
)

seller_metrics = (
    order_items_enriched.groupby("seller_id", as_index=False)
    .agg(
        seller_state=("seller_state", "first"),
        orders=("order_id", "nunique"),
        gmv=("item_revenue", "sum"),
        avg_review_score=("review_score", "mean"),
        negative_reviews=("is_negative_review", "sum"),
        reviews=("review_score", "count"),
        late_orders=("is_late", "sum"),
        canceled_orders=("is_canceled", "sum"),
    )
)
seller_metrics["negative_review_rate"] = (
    seller_metrics["negative_reviews"] / seller_metrics["reviews"].replace(0, pd.NA)
)
seller_metrics["late_delivery_rate"] = (
    seller_metrics["late_orders"] / seller_metrics["orders"].replace(0, pd.NA)
)
seller_metrics["cancellation_rate"] = (
    seller_metrics["canceled_orders"] / seller_metrics["orders"].replace(0, pd.NA)
)

state_metrics = (
    orders_enriched.groupby("customer_state", as_index=False)
    .agg(
        customers=("customer_unique_id", "nunique"),
        orders=("order_id", "nunique"),
        gmv=("gmv", "sum"),
        avg_order_value=("gmv", "mean"),
        avg_review_score=("review_score", "mean"),
        late_orders=("is_late", "sum"),
        canceled_orders=("is_canceled", "sum"),
    )
    .rename(columns={"customer_state": "state"})
)
state_metrics["late_delivery_rate"] = (
    state_metrics["late_orders"] / state_metrics["orders"].replace(0, pd.NA)
)
state_metrics["cancellation_rate"] = (
    state_metrics["canceled_orders"] / state_metrics["orders"].replace(0, pd.NA)
)

monthly_metrics = (
    orders_enriched.groupby("order_month", as_index=False)
    .agg(
        orders=("order_id", "nunique"),
        customers=("customer_unique_id", "nunique"),
        gmv=("gmv", "sum"),
        avg_order_value=("gmv", "mean"),
        avg_review_score=("review_score", "mean"),
        late_orders=("is_late", "sum"),
        delivered_orders=("delivery_days", "count"),
        canceled_orders=("is_canceled", "sum"),
    )
    .sort_values("order_month")
)
monthly_metrics["late_delivery_rate"] = (
    monthly_metrics["late_orders"]
    / monthly_metrics["delivered_orders"].replace(0, pd.NA)
)
monthly_metrics["cancellation_rate"] = (
    monthly_metrics["canceled_orders"] / monthly_metrics["orders"].replace(0, pd.NA)
)

payment_metrics = (
    order_payments.groupby("payment_type", as_index=False)
    .agg(payments=("order_id", "count"), revenue=("payment_value", "sum"))
    .sort_values("revenue", ascending=False)
)
payment_metrics["share"] = payment_metrics["revenue"] / payment_metrics["revenue"].sum()

customer_order_counts = orders_enriched.groupby("customer_unique_id")["order_id"].nunique()
repeat_customers = int((customer_order_counts > 1).sum())
unique_customers = int(customer_order_counts.count())

delivered = orders_enriched[orders_enriched["delivery_days"].notna()]
last_complete_month = "2018-08"
previous_month = "2018-07"
monthly_index = monthly_metrics.set_index("order_month")

kpis = {
    "gmv": float(orders_enriched["gmv"].sum()),
    "orders": int(orders_enriched["order_id"].nunique()),
    "customers": unique_customers,
    "aov": float(orders_enriched["gmv"].mean()),
    "avg_review_score": float(orders_enriched["review_score"].mean()),
    "late_delivery_rate": float((delivered["delay_days"] > 0).mean()),
    "cancellation_rate": float(orders_enriched["is_canceled"].mean()),
    "repeat_purchase_rate": repeat_customers / unique_customers,
    "gmv_mom": pct_change(
        monthly_index.loc[last_complete_month, "gmv"],
        monthly_index.loc[previous_month, "gmv"],
    ),
    "orders_mom": pct_change(
        monthly_index.loc[last_complete_month, "orders"],
        monthly_index.loc[previous_month, "orders"],
    ),
    "customers_mom": pct_change(
        monthly_index.loc[last_complete_month, "customers"],
        monthly_index.loc[previous_month, "customers"],
    ),
    "aov_mom": pct_change(
        monthly_index.loc[last_complete_month, "avg_order_value"],
        monthly_index.loc[previous_month, "avg_order_value"],
    ),
}

dashboard_data = {
    "kpis": kpis,
    "monthly": records(monthly_metrics.tail(24)),
    "payments": records(payment_metrics),
    "top_categories": records(
        category_metrics.sort_values("gmv", ascending=False).head(8)
    ),
    "top_category_risk": records(
        category_metrics[category_metrics["orders"] >= 50]
        .sort_values("risk_score", ascending=False)
        .head(8)
    ),
    "top_states": records(state_metrics.sort_values("customers", ascending=False).head(12)),
    "seller_risk": records(
        seller_metrics[seller_metrics["orders"] >= 50]
        .sort_values("negative_review_rate", ascending=False)
        .head(10)
    ),
}

orders_enriched.to_csv(EXPORT_DIR / "orders_enriched.csv", index=False)
order_items_enriched.to_csv(EXPORT_DIR / "order_items_enriched.csv", index=False)
category_metrics.to_csv(EXPORT_DIR / "category_metrics.csv", index=False)
seller_metrics.to_csv(EXPORT_DIR / "seller_metrics.csv", index=False)
state_metrics.to_csv(EXPORT_DIR / "state_metrics.csv", index=False)
monthly_metrics.to_csv(EXPORT_DIR / "monthly_metrics.csv", index=False)
payment_metrics.to_csv(EXPORT_DIR / "payment_metrics.csv", index=False)

with (EXPORT_DIR / "dashboard_summary.json").open("w", encoding="utf-8") as file:
    json.dump(dashboard_data, file, indent=2)

print(f"Exported BI dashboard data to {EXPORT_DIR}")
