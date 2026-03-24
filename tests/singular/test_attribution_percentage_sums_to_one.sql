-- Validate that attribution percentages sum to 1.0 per customer per month
select
    customer_key,
    revenue_month,
    round(sum(attribution_percentage), 4) as pct_sum
from {{ ref('fact_revenue_attribution') }}
group by 1, 2
having abs(sum(attribution_percentage) - 1.0) > 0.01
