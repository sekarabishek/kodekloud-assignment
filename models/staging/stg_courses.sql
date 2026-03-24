select
    trim("Course Name") as course_name,
    upper(trim("Course Type")) as course_type,
    trim("Course Instructor") as course_instructor
from {{ ref('courses') }}
