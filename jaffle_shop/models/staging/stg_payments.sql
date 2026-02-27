with source as (
    select * from {{ ref('raw_payments') }}
)

select
    id                                          as payment_id,
    order_id,
    payment_method,
    amount / 100.0                              as amount
from source
