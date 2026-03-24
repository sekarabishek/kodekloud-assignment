with orders as (

    select *
    from (
        select
            fo.*,
            row_number() over (
                partition by fo.customer_key, date_trunc('month', fo.order_created_at)::date
                order by fo.order_created_at desc, fo.order_key desc
            ) as month_order_rank
        from {{ ref('fact_order') }} fo
        where fo.subscription_type in ('MONTHLY', 'YEARLY')
          and fo.customer_key is not null
          and fo.monthly_value > 0
    ) x
    where month_order_rank = 1

),

consumption as (

    select *
    from {{ ref('fact_consumption') }}
    where is_revenue_eligible = true

),

paid_monthly_consumption as (

    select
        customer_key,
        consumption_month,
        sum(total_minutes_consumed) as total_paid_minutes_consumed
    from consumption
    group by 1,2

),

joined as (

    select
        c.customer_key,
        c.course_key,
        o.order_key,
        c.date_key,
        c.consumption_month as revenue_month,
        o.subscription_type,
        o.monthly_value as subscription_monthly_value,
        c.total_minutes_consumed as course_minutes_consumed,
        pmc.total_paid_minutes_consumed,
        round(
            c.total_minutes_consumed::numeric
            / nullif(pmc.total_paid_minutes_consumed, 0),
            4
        ) as attribution_percentage
    from consumption c
    inner join paid_monthly_consumption pmc
        on c.customer_key = pmc.customer_key
       and c.consumption_month = pmc.consumption_month
    inner join orders o
        on c.customer_key = o.customer_key
       and date_trunc('month', o.order_created_at)::date = c.consumption_month
),

final as (

    select
        row_number() over (
            order by customer_key, course_key, order_key, revenue_month
        ) as revenue_key,
        customer_key,
        course_key,
        order_key,
        date_key,
        revenue_month,
        subscription_type,
        subscription_monthly_value,
        course_minutes_consumed,
        total_paid_minutes_consumed,
        attribution_percentage,
        round(subscription_monthly_value * attribution_percentage, 2) as attributed_revenue,
        round(subscription_monthly_value * attribution_percentage * 0.20, 2) as instructor_royalty,
        false as is_free_course,
        current_timestamp as created_at,
        current_timestamp as updated_at
    from joined

)

select *
from final
