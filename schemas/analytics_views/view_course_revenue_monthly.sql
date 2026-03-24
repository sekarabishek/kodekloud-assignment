select
    r.revenue_month as month,
    c.course_name,
    c.course_type,
    c.course_instructor as instructor,

    sum(r.attributed_revenue) as total_revenue,
    round(avg(r.attributed_revenue), 2) as avg_revenue_per_student,

    sum(r.course_minutes_consumed) as total_minutes_consumed,
    round(sum(r.course_minutes_consumed) / 60.0, 2) as total_hours_consumed,
    round(avg(r.course_minutes_consumed), 2) as avg_minutes_per_student,

    count(distinct r.customer_key) as unique_students,
    count(distinct case
        when r.course_minutes_consumed >= 60 then r.customer_key
    end) as students_1plus_hours,

    round(
        count(distinct case
            when r.course_minutes_consumed >= 60 then r.customer_key
        end)::numeric * 100
        / nullif(count(distinct r.customer_key), 0),
        2
    ) as engagement_rate_pct,

    round(sum(r.instructor_royalty), 2) as total_instructor_royalty,

    rank() over (
        partition by r.revenue_month
        order by sum(r.attributed_revenue) desc
    ) as revenue_rank,

    rank() over (
        partition by r.revenue_month
        order by count(distinct r.customer_key) desc
    ) as popularity_rank

from {{ ref('fact_revenue_attribution') }} r
join {{ ref('dim_course') }} c
  on r.course_key = c.course_key
where c.course_type = 'PAID'
group by
    r.revenue_month,
    c.course_name,
    c.course_type,
    c.course_instructor
order by
    r.revenue_month desc,
    total_revenue desc
