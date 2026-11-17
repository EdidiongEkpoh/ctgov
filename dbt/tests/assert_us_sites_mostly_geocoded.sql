{{ config(severity='warn') }}

SELECT COUNT_IF(is_geocoded) / NULLIF(COUNT(*), 0) AS geocoded_share
FROM {{ ref('slv_sites__county') }}
WHERE zip5 IS NOT NULL 
HAVING COUNT_IF(is_geocoded) / NULLIF(COUNT(*), 0) < 0.95