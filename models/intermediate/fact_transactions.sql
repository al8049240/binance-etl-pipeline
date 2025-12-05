{{ config(
    materialized='table',
    tags=['silver']
) }}

with tx as (
    select *
    from {{ ref('staging_transactions') }}
    where status = 'completed'
),

users as (
    select *
    from {{ ref('staging_users') }}
),

rates as (
    select *
    from {{ ref('staging_rates') }}
)

select
    tx.TXN_ID,
    tx.USER_ID,
    tx.DST_CUR,
    tx.DST_AMT,
    r.CLOSE_USD,
     round(
        case
            when tx.DST_CUR = 'USDT' then tx.DST_AMT
            else tx.DST_AMT * r.CLOSE_USD
        end
    , 2) as DST_AMT_USD,
    tx.CRE_AT,
    u.KYC_LVL
from tx
left join users u
    on u.USER_ID = tx.USER_ID
    --and tx.CRE_AT >= u.CRE_AT   -- Implement SCD 2 and get exact KYC_LVL
   -- and tx.CRE_AT <= u.UPD_AT
left join rates r
    on r.symbol = concat(tx.DST_CUR, 'USDT')
    and tx.CRE_AT between r.OPEN_AT and r.CLOSE_AT
where r.CLOSE_USD is not null
