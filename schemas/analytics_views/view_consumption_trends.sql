select
    fc.consumption_month as month,
    dc.course_name,
    dc.course_type,
    dc.course_instructor as instructor,
    sum(fc.total_minutes_consumed) as total_minutes,
    count(distinct fc.customer_key) as unique_users,
    round(sum(fc.total_minutes_consumed)::numeric / nullif(count(distinct fc.customer_key), 0), 2) as avg_minutes_per_user,
    round(sum(fc.total_hours_consumed), 2) as total_hours
from {{ ref('fact_consumption') }} fc
join {{ ref('dim_course') }} dc
  on fc.course_key = dc.course_key
group by 1, 2, 3, 4
order by 1 desc, total_minutes desc
