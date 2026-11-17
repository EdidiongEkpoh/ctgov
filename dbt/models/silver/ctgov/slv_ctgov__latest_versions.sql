{{ config(materialized='table') }}

SELECT nct_id
    , {{ parse_partial_date('last_update_post_date_raw') }} AS last_update_post_date
    , record_hash
    , record 
    , loaded_at
    , COUNT(*) OVER (PARTITION BY nct_id) AS versions_stored
FROM {{ ref('brz_ctgov__studies') }}
WHERE nct_id IS NOT NULL 
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY nct_id
    ORDER BY {{ parse_partial_date('last_update_post_date_raw') }} DESC NULLS last, 
            loaded_at DESC,
            record_hash
) = 1