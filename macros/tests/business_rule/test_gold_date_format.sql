{% test valid_gold_date_format(model) %}

with checks as (
    select
        -- DAY should be timestamp truncated to day (00:00:00)
        case
            when extract(hour from day) = 0
             and extract(minute from day) = 0
             and extract(second from day) = 0
            then true else false
        end as valid_day,

        -- Month must be numeric 1–12
        case
            when mon between 1 and 12 then true else false
        end as valid_month,

        -- Year should be >= 2000 (or adjust if needed)
        case
            when yr >= 2000 then true else false
        end as valid_year,

        -- Quarter should be between 1–4
        case
            when qtr between 1 and 4 then true else false
        end as valid_quarter
    from {{ model }}
)

select *
from checks
where not (valid_day and valid_month and valid_year and valid_quarter)

{% endtest %}
