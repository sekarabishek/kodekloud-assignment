-- Validate that all attributed revenue values are non-negative
select
    revenue_key,
    attributed_revenue
from {{ ref('fact_revenue_attribution') }}
where attributed_revenue < 0
