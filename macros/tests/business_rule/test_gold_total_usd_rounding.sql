{% test valid_total_usd_rounding(model) %}

with checks as (
    select
        total_usd,
        -- check if value equals its 2-decimal rounded version
        case
            when total_usd = round(total_usd, 2) then true
            else false
        end as is_rounded
    from {{ model }}
)

select *
from checks
where is_rounded = false

{% endtest %}
