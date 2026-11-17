{{ config(materialized='incremental', incremental_strategy='append', on_schema_change='append_new_columns')}}

WITH new_rows AS (
    SELECT record 
        , file_name
        , loaded_at
    FROM {{ source('staging', 'cdc_places_county') }}
    {% if is_incremental() %}
    WHERE loaded_at > (SELECT COALESCE(MAX(loaded_at), '1900-01-01'::timestamp_ltz) FROM {{ this }})
    {% endif %}
)
, hashed AS (
    SELECT REGEXP_SUBSTR(file_name, 'release=([0-9]{4})', 1, 1, 'e', 1) AS release
        , record:locationid::string AS location_id
        , record:measureid::string AS measure_id
        , record:datavaluetypeid::string AS data_value_type_id
        , MD5(TO_JSON(record)) AS record_hash
        , record
        , file_name AS source_file
        , loaded_at
    FROM new_rows
)
SELECT *
FROM hashed
{% if is_incremental() %}
WHERE NOT EXISTS(
    SELECT 1
    FROM {{ this }} AS existing
    WHERE existing.record_hash = hashed.record_hash
)
{% endif %}
QUALIFY ROW_NUMBER() OVER (PARTITION BY record_hash ORDER BY loaded_at, source_file) = 1