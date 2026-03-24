with monthly_customer_revenue as (

    select
        revenue_month,
        customer_key,
        sum(subscription_monthly_value) as customer_mrr,
        max(subscription_type) as subscription_type
    from {{ ref('fact_revenue_attribution') }}
    group by 1,2

),

mrr_with_previous as (

    select
        revenue_month,
        customer_key,
        customer_mrr,
        subscription_type,
        lag(customer_mrr) over (
            partition by customer_key
            order by revenue_month
        ) as previous_month_mrr,
        lag(revenue_month) over (
            partition by customer_key
            order by revenue_month
        ) as previous_month
    from monthly_customer_revenue

),

mrr_movements as (

    select
        revenue_month,
        sum(customer_mrr) as total_mrr,

        sum(
            case
                when previous_month_mrr is null then customer_mrr
                else 0
            end
        ) as new_mrr,

        0::numeric(12,2) as churned_mrr,

        sum(
            case
                when previous_month_mrr is not null
                 and customer_mrr > previous_month_mrr
                    then customer_mrr - previous_month_mrr
                else 0
            end
        ) as expansion_mrr,

        sum(
            case
                when previous_month_mrr is not null
                 and customer_mrr < previous_month_mrr
                    then previous_month_mrr - customer_mrr
                else 0
            end
        ) as contraction_mrr,

        count(distinct customer_key) as total_customers,

        count(distinct case
            when previous_month_mrr is null then customer_key
        end) as new_customers,

        count(distinct case
            when previous_month_mrr is not null then customer_key
        end) as retained_customers

    from mrr_with_previous
    group by 1

)

select
    revenue_month as month,
    total_mrr as mrr,
    total_mrr * 12 as arr,
    new_mrr,
    churned_mrr,
    expansion_mrr,
    contraction_mrr,
    (new_mrr - churned_mrr + expansion_mrr - contraction_mrr) as net_new_mrr,

    round(
        (
            (new_mrr - churned_mrr + expansion_mrr - contraction_mrr)
            / nullif(lag(total_mrr) over (order by revenue_month), 0)
        ) * 100,
        2
    ) as mrr_growth_rate_pct,

    total_customers,
    new_customers,
    retained_customers,

    round(
        (
            retained_customers::numeric
            / nullif(lag(total_customers) over (order by revenue_month), 0)
        ) * 100,
        2
    ) as customer_retention_rate_pct,

    round(total_mrr / nullif(total_customers, 0), 2) as arpu,

    round(
        (new_mrr + expansion_mrr)
        / nullif((churned_mrr + contraction_mrr), 0),
        2
    ) as quick_ratio

from mrr_movements
order by revenue_month desc
