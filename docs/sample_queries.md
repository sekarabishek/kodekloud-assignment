# Sample Queries

This document contains sample business queries and validation queries for the assignment output.

---

## 1. Monthly MRR and ARR

Use this query to view monthly recurring revenue and annual recurring revenue metrics.

```sql
select *
from public.view_monthly_mrr_arr;
```

---

## 2. Top 10 Courses by Revenue

Use this query to identify the top-performing courses by attributed revenue.

```sql
select
    month,
    course_name,
    instructor,
    total_revenue,
    unique_students,
    total_instructor_royalty
from public.view_course_revenue_monthly
order by total_revenue desc
limit 10;
```

---

## 3. Instructor Royalty Totals

Use this query to calculate total instructor royalties across all courses.

```sql
select
    instructor,
    round(sum(total_revenue), 2) as total_revenue,
    round(sum(total_instructor_royalty), 2) as total_instructor_royalty
from public.view_course_revenue_monthly
group by instructor
order by total_instructor_royalty desc;
```

---

## 4. Revenue Attribution Percentage Validation

This query validates that attribution percentages sum to 100% for each customer and month.

```sql
select
    customer_key,
    revenue_month,
    round(sum(attribution_percentage), 4) as pct_sum,
    round(sum(attributed_revenue), 2) as revenue_sum,
    count(*) as row_count
from public.fact_revenue_attribution
group by 1, 2
having abs(sum(attribution_percentage) - 1.0) > 0.01
order by 2, 1
limit 20;
```

**Expected result:** zero rows.

---

## 5. Revenue Tie-Out Validation

This query validates that total attributed revenue matches the selected monthly subscription value for each customer and month.

```sql
select
    r.customer_key,
    r.revenue_month,
    round(sum(r.attributed_revenue), 2) as attributed_sum,
    round(max(r.subscription_monthly_value), 2) as monthly_value
from public.fact_revenue_attribution r
group by 1, 2
having abs(sum(r.attributed_revenue) - max(r.subscription_monthly_value)) > 0.05
order by 2, 1
limit 20;
```

**Expected result:** zero rows.

---

## 6. Fact Order Summary

Use this query to inspect subscription classifications in the order fact table.

```sql
select
    subscription_type,
    subscription_tier,
    subscription_interval_months,
    count(*) as order_count
from public.fact_order
group by 1, 2, 3
order by order_count desc;
```

---

## 7. Fact Consumption Revenue Eligibility Summary

Use this query to compare paid vs free course consumption.

```sql
select
    is_revenue_eligible,
    count(*) as row_count,
    sum(total_minutes_consumed) as total_minutes_consumed
from public.fact_consumption
group by 1
order by 1;
```

---

## 8. Monthly Attributed Revenue Summary

Use this query to validate total attributed revenue by month.

```sql
select
    revenue_month,
    round(sum(attributed_revenue), 2) as total_attributed_revenue
from public.fact_revenue_attribution
group by 1
order by 1;
```

---

## 9. View: Course Revenue Monthly Sample Output

Use this query to inspect the course revenue analytics view.

```sql
select *
from public.view_course_revenue_monthly
limit 10;
```

---

## 10. View: Monthly MRR/ARR Sample Output

Use this query to inspect the MRR/ARR analytics view.

```sql
select *
from public.view_monthly_mrr_arr;
```
