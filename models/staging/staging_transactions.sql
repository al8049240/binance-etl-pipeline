{{ config(
    materialized='table',
    tags=['bronze']
) }}

SELECT
    txn_id      AS TXN_ID,
    user_id     AS USER_ID,
    source_currency      AS SRC_CUR,
    destination_currency AS DST_CUR,
    CAST(source_amount AS NUMERIC)      AS SRC_AMT,
    CAST(destination_amount AS NUMERIC) AS DST_AMT,
    CAST(created_at AS TIMESTAMP)       AS CRE_AT,
    status       AS STATUS
FROM {{ source('raw', 'transactions') }}
