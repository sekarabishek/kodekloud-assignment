-- Validate that no free courses appear in revenue attribution
select
    r.revenue_key,
    r.course_key,
    c.course_name,
    c.course_type
from {{ ref('fact_revenue_attribution') }} r
join {{ ref('dim_course') }} c on r.course_key = c.course_key
where c.course_type = 'FREE'
