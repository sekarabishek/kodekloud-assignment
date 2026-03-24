with consumption as (

    select *
    from {{ ref('stg_consumption') }}

),

customers as (

    select *
    from {{ ref('dim_customer') }}
    where is_current = true

),

courses as (

    select *
    from {{ ref('dim_course') }}

),

base as (

    select
        c.user_id,
        dc.customer_key,
        dc2.course_key,
        c.consumption_month,
        to_char(c.consumption_month, 'YYYYMMDD')::bigint as date_key,
        c.minutes_consumed,
        dc2.is_revenue_generating
    from consumption c
    left join customers dc
        on c.user_id = dc.customer_id
    left join courses dc2
        on c.course_name = dc2.course_name

),

aggregated as (

    select
        customer_key,
        course_key,
        date_key,
        consumption_month,
        sum(minutes_consumed) as total_minutes_consumed,
        round(sum(minutes_consumed) / 60.0, 2) as total_hours_consumed,
        null::bigint as unique_sessions,
        null::numeric(5,2) as completion_percentage,
        is_revenue_generating
    from base
    where customer_key is not null
      and course_key is not null
    group by 1,2,3,4,9

),

final as (

    select
        row_number() over (
            order by customer_key, course_key, consumption_month
        ) as consumption_key,
        customer_key,
        course_key,
        date_key,
        consumption_month,
        total_minutes_consumed,
        total_hours_consumed,
        unique_sessions,
        completion_percentage,
        round(
            total_minutes_consumed::numeric
            / nullif(sum(total_minutes_consumed) over (partition by customer_key, consumption_month), 0),
            4
        ) as consumption_percentage_of_month,
        is_revenue_generating as is_revenue_eligible,
        current_timestamp as created_at,
        current_timestamp as updated_at
    from aggregated

)

select *
from final
