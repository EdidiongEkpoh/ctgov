{{ config(materialized='incremental', incremental_strategy='append', on_schema_change='append_new_columns') }}

WITH new_rows AS (
    SELECT record
        , file_name
        , loaded_at
    FROM {{ source('staging', 'ctgov_studies') }}
    {% if is_incremental() %}
    WHERE loaded_at > (SELECT COALESCE(MAX(loaded_at), '1900-01-01'::timestamp_ltz) FROM {{ this }})
    {% endif %}
)
, hashed AS (
    SELECT record:protocolSection:identificationModule:nctId::string AS nct_id
        , record:protocolSection:statusModule:lastUpdatePostDateStruct:date::string AS last_update_post_date_raw
        , MD5(TO_JSON(
            iff(record:derivedSection:miscInfoModule IS NULL, record, OBJECT_INSERT(record, 'derivedSection', OBJECT_DELETE(record:derivedSection, 'miscInfoModule'), TRUE))
        )) AS record_hash
        , record
        , file_name AS source_file
        , loaded_at
    FROM new_rows
)
SELECT *
FROM hashed
{% if is_incremental() %}
WHERE NOT EXISTS (
    SELECT 1 
    FROM {{ this }} AS existing
    WHERE existing.record_hash = hashed.record_hash
)
{% endif %}
QUALIFY ROW_NUMBER() OVER (PARTITION BY record_hash ORDER BY loaded_at, source_file) = 1