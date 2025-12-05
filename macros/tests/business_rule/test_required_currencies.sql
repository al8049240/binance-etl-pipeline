{% test required_currencies(model, column_name, required_list) %}

-- required currencies as a UNION ALL table
with required as (
    {% for cur in required_list %}
        select '{{ cur }}' as cur
        {% if not loop.last %} union all {% endif %}
    {% endfor %}
),

distinct_vals as (
    select distinct replace({{ column_name }} || 'USDT', 'USDTUSDT', 'USDT') as cur
    from {{ model }}
),

missing as (
    select r.cur
    from required r
    left join distinct_vals d
        on r.cur = d.cur
    where d.cur is null
)

select *
from missing

{% endtest %}