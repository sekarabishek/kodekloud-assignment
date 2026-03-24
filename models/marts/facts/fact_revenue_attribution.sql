-- Revenue Attribution Fact Table
-- Grain: One row per customer per course per revenue month
-- Business Logic: Subscription revenue is attributed to paid courses
-- based on the percentage of watch time for that month
-- Instructor royalties are calculated at 20% of attributed revenue

with orders as (

    -- Get the latest order per customer per month
    -- This prevents double-counting when a customer has multiple orders in the same month
    select *
    from (
        select
            fo.*,
            row_number() over (
                partition by fo.customer_key, date_trunc('month', fo.order_created_at)::date
                order by fo.order_created_at desc, fo.order_key desc
            ) as month_order_rank
        from {{ ref('fact_order') }} fo
        where fo.subscription_type in ('MONTHLY', 'YEARLY')  -- Only subscription orders
          and fo.customer_key is not null                     -- Exclude anonymous orders
          and fo.monthly_value > 0                            -- Exclude refunds/credits
    ) x
    where month_order_rank = 1

),

consumption as (

    -- Only paid course consumption is used for revenue attribution
    -- Free course minutes are tracked in fact_consumption but excluded here
    select *
    from {{ ref('fact_consumption') }}
    where is_revenue_eligible = true

),

paid_monthly_consumption as (

    -- Total paid-course minutes per customer per month
    -- This is the denominator for the attribution percentage calculation
    select
        customer_key,
        consumption_month,
        sum(total_minutes_consumed) as total_paid_minutes_consumed
    from consumption
    group by 1,2

),

joined as (

    -- Join consumption with orders to calculate attribution
    -- A customer's October consumption is matched to their October order
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

        -- Attribution percentage = course minutes / total paid minutes
        -- Example: 120 min Course A / 600 min total = 0.2000 (20%)
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

        -- Attributed revenue = monthly subscription value x attribution percentage
        -- Example: $12.50 x 0.2000 = $2.50
        round(subscription_monthly_value * attribution_percentage, 2) as attributed_revenue,

        -- Instructor royalty = 20% of attributed revenue
        -- Example: $2.50 x 0.20 = $0.50
        round(subscription_monthly_value * attribution_percentage * 0.20, 2) as instructor_royalty,

        -- Always false: free courses are excluded in the consumption CTE above
        false as is_free_course,

        current_timestamp as created_at,
        current_timestamp as updated_at

    from joined

)

select *
from final
