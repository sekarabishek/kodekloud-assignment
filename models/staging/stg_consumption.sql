select
    cast("User ID" as bigint) as user_id,
    trim("Course Name") as course_name,
    cast("Minutes Consumed" as integer) as minutes_consumed,
    date '2022-10-01' as consumption_month
from {{ ref('consumption_october') }}
where trim("Course Name") != ''
  and "Course Name" is not null
