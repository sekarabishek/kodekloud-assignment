select
    row_number() over (order by course_name) as course_key,
    course_name,
    course_type,
    course_instructor,
    case
        when course_type = 'PAID' then true
        else false
    end as is_revenue_generating,
    null::integer as total_duration_minutes,
    null::integer as lesson_count,
    null::integer as enrollment_count,
    current_timestamp as created_at,
    current_timestamp as updated_at
from {{ ref('stg_courses') }}
