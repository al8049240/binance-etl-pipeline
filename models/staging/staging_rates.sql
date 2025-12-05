{{ config(
    materialized='table',
    tags=['bronze']
) }}

SELECT
    symbol                    AS SYMBOL,
    TIMESTAMP_MILLIS(open_time)    AS OPEN_AT,
    TIMESTAMP_MILLIS(close_time)   AS CLOSE_AT,
    open                       AS OPEN_USD,
    high                       AS HIGH_USD,
    low                        AS LOW_USD,
    close                      AS CLOSE_USD,
    volume                     AS VOL,
    quote_volume               AS QVOL,
    trades                     AS TRADES,
    taker_buy_volume           AS TAKER_VOL,
    taker_buy_quote_volume     AS TAKER_QVOL
FROM {{source('raw', 'binance_klines') }}