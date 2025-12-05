{% test check_usd_conversion(model, column_name) %}

-- Fail rows that violate the CASE WHEN logic
select
    *
from {{ model }}
where
    (
        -- Case 1: USDT transactions must match DST_AMT exactly
        DST_CUR = 'USDT'
        and round(DST_AMT_USD, 2) != round(DST_AMT, 2)
    )
    OR
    (
        -- Case 2: Non-USDT must match DST_AMT * CLOSE_USD
        DST_CUR != 'USDT'
        and round(DST_AMT_USD, 2) != round(DST_AMT * CLOSE_USD, 2)
    )

{% endtest %}