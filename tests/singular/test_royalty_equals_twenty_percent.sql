-- Validate that instructor royalty equals 20% of attributed revenue
select
    revenue_key,
    attributed_revenue,
    instructor_royalty,
    round(attributed_revenue * 0.20, 2) as expected_royalty
from {{ ref('fact_revenue_attribution') }}
where abs(instructor_royalty - round(attributed_revenue * 0.20, 2)) > 0.01
