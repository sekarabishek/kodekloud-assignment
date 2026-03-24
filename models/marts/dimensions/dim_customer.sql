select
    row_number() over (order by customer_id) as customer_key,
    customer_id,
    first_paid_order_date,
    first_order_date,
    total_spent,
    null::text as customer_status,
    first_order_date as effective_from_date,
    null::timestamp as effective_to_date,
    true as is_current,
    current_timestamp as created_at,
    current_timestamp as updated_at
from {{ ref('stg_customers') }}
