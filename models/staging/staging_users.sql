{{ config(
    materialized='table',
    tags=['bronze']
) }}

WITH RAW AS (
    SELECT
        user_id        AS USER_ID,
        kyc_level      AS KYC_LVL,
        CAST(created_at AS TIMESTAMP) AS CRE_AT,
        CAST(updated_at AS TIMESTAMP) AS UPD_AT
    FROM {{ source('raw', 'users') }}
)

SELECT * FROM RAW
