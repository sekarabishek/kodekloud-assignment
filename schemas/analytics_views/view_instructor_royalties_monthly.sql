select
    r.revenue_month as month,
    c.course_instructor as instructor,
    count(distinct c.course_name) as courses_count,
    round(sum(r.attributed_revenue), 2) as total_course_revenue,
    round(sum(r.instructor_royalty), 2) as royalty_amount,
    count(distinct r.customer_key) as unique_students
from {{ ref('fact_revenue_attribution') }} r
join {{ ref('dim_course') }} c
  on r.course_key = c.course_key
where c.course_type = 'PAID'
group by 1, 2
order by 1 desc, royalty_amount desc
