# dbt Mart Model Layout

The marts layer is split by consumer type so shared lifecycle logic can be reused without mixing externally curated analytics models with internal operational monitoring models.

- `shared/`: conformed dimensions and reusable lifecycle facts
- `customer_analytics/`: customer-facing reporting and product analytics
- `internal_mail_tracking/`: internal workflow, SLA, and operational monitoring models

Recommended modeling flow:

1. Build conformed dimensions and reusable facts in `shared/`
2. Derive customer-safe reporting models in `customer_analytics/`
3. Derive operationally rich tracking models in `internal_mail_tracking/`
