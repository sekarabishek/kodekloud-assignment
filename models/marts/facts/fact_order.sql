with orders as (

    select *
    from {{ ref('stg_orders') }}

),

customers as (

    select *
    from {{ ref('dim_customer') }}

),

final as (

    select
        row_number() over (order by o.order_id) as order_key,
        o.order_id,
        o.order_number,
        c.customer_key,
        to_char(o.order_created_at, 'YYYYMMDD')::bigint as date_key,
        o.order_created_at,
        o.line_items,
        o.billing_address_country as billing_country,

        case
            when upper(o.line_items) like '%YEARLY%' then 'YEARLY'
            when upper(o.line_items) like '%MONTHLY%' then 'MONTHLY'
            else null
        end as subscription_type,

        case
            when upper(o.line_items) like '%PROFESSIONAL%' then 'PROFESSIONAL'
            when upper(o.line_items) like '%SUBSCRIPTION%' then 'STANDARD'
            else null
        end as subscription_tier,

        case
            when upper(o.line_items) like '%YEARLY%' then 12
            when upper(o.line_items) like '%MONTHLY%' then 1
            else null
        end as subscription_interval_months,

        o.net_usd as net_amount_usd,

        case
            when upper(o.line_items) like '%YEARLY%' then round(o.net_usd / 12.0, 2)
            when upper(o.line_items) like '%MONTHLY%' then o.net_usd
            else o.net_usd
        end as monthly_value,

        case
            when row_number() over (
                partition by o.customer_id
                order by o.order_created_at, o.order_id
            ) = 1 then true
            else false
        end as is_first_order,

        case
            when row_number() over (
                partition by o.customer_id
                order by o.order_created_at desc, o.order_id desc
            ) = 1 then true
            else false
        end as is_latest_order,

        row_number() over (
            partition by o.customer_id
            order by o.order_created_at, o.order_id
        ) as order_sequence,

        current_timestamp as created_at,
        current_timestamp as updated_at

    from orders o
    left join customers c
        on o.customer_id = c.customer_id
       and c.is_current = true

)

select *
from final
