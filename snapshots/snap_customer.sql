{% snapshot snap_customer %}

{{
    config(
      target_schema='public',
      unique_key='customer_id',
      strategy='check',
      check_cols=['total_spent', 'first_paid_order_date']
    )
}}

select
    customer_id,
    first_paid_order_date,
    first_order_date,
    total_spent
from {{ ref('stg_customers') }}

{% endsnapshot %}
