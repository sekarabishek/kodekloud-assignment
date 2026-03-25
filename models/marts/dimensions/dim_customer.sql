-- Customer Dimension (SCD Type 2)
-- Uses dbt snapshot for historical tracking
-- Grain: One row per customer per version

select
    row_number() over (order by customer_id, dbt_valid_from) as customer_key,
    customer_id,
    first_paid_order_date,
    first_order_date,
    total_spent,
    null::text as customer_status,
    dbt_valid_from as effective_from_date,
    dbt_valid_to as effective_to_date,
    case
        when dbt_valid_to is null then true
        else false
    end as is_current,
    current_timestamp as created_at,
    current_timestamp as updated_at
from {{ ref('snap_customer') }}
