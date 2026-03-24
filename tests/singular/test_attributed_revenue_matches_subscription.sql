-- Validate that total attributed revenue matches subscription monthly value
select
    customer_key,
    revenue_month,
    round(sum(attributed_revenue), 2) as attributed_sum,
    round(max(subscription_monthly_value), 2) as monthly_value
from {{ ref('fact_revenue_attribution') }}
group by 1, 2
having abs(sum(attributed_revenue) - max(subscription_monthly_value)) > 0.05
