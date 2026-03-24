select
    cast("Order ID" as bigint) as order_id,
    trim("Order Number") as order_number,

    case
        when cast("Order Created At" as text) like '%/%'
            then to_timestamp(cast("Order Created At" as text), 'DD/MM/YY HH24:MI')
        when cast("Order Created At" as text) like '%-%'
            then cast("Order Created At" as timestamp)
        else null
    end as order_created_at,

    cast(nullif(trim(cast("Customer ID" as text)), '') as bigint) as customer_id,
    trim("Line Items") as line_items,
    trim("Billing Address Country") as billing_address_country,
    cast("Net (USD)" as numeric(12,2)) as net_usd
from {{ ref('orders') }}
