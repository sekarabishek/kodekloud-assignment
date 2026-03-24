with raw as (

    select
        cast("Customer ID" as bigint) as customer_id,

        case
            when "First Paid Order Date" like '%/%'
                then to_timestamp("First Paid Order Date", 'DD/MM/YY HH24:MI')
            when "First Paid Order Date" like '%-%'
                then cast("First Paid Order Date" as timestamp)
            else null
        end as first_paid_order_date,

        case
            when "First Order Date" like '%/%'
                then to_timestamp("First Order Date", 'DD/MM/YY HH24:MI')
            when "First Order Date" like '%-%'
                then cast("First Order Date" as timestamp)
            else null
        end as first_order_date,

        cast("Total Spent" as numeric(10,2)) as total_spent

    from {{ ref('customers') }}
    where "Customer ID" is not null
      and trim(cast("Customer ID" as text)) != ''

),

deduplicated as (

    select
        customer_id,
        first_paid_order_date,
        first_order_date,
        total_spent,
        row_number() over (
            partition by customer_id
            order by total_spent desc
        ) as rn
    from raw

)

select
    customer_id,
    first_paid_order_date,
    first_order_date,
    total_spent
from deduplicated
where rn = 1
