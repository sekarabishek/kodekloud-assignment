with latest_orders as (

    select
        customer_key,
        order_created_at as last_order_date,
        subscription_type as current_plan,
        monthly_value as mrr,
        net_amount_usd
    from {{ ref('fact_order') }}
    where is_latest_order = true
      and subscription_type is not null

),

customers as (

    select *
    from {{ ref('dim_customer') }}
    where is_current = true

)

select
    c.customer_id,
    coalesce(o.current_plan, 'NONE') as current_plan,
    coalesce(o.mrr, 0) as mrr,
    c.first_order_date as start_date,
    o.last_order_date,
    c.total_spent,
    case
        when o.last_order_date >= date '2022-10-01' then 'ACTIVE'
        when o.last_order_date >= date '2022-10-01' - interval '90 days' then 'AT_RISK'
        when o.last_order_date is not null then 'CHURNED'
        else 'UNKNOWN'
    end as status
from customers c
left join latest_orders o
  on c.customer_key = o.customer_key
order by c.total_spent desc
