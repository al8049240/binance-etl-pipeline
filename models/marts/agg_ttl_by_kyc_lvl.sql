{{ config(
    materialized='table',
    tags=['gold']
) }}

select
    TIMESTAMP_TRUNC(CRE_AT, DAY)       as DAY,
    EXTRACT(MONTH FROM CRE_AT)         as MON,   -- numeric month 1-12
    EXTRACT(YEAR FROM CRE_AT)          as YR,    -- numeric year
    EXTRACT(QUARTER FROM CRE_AT)       as QTR,   -- quarter number 1-4
    KYC_LVL                             as KYC,
    round(sum(DST_AMT_USD) , 2)                   as TOTAL_USD,
    count(distinct TXN_ID)              as NUM_TXN
from {{ ref('fact_transactions') }}
group by 1,2,3,4,5
order by DAY