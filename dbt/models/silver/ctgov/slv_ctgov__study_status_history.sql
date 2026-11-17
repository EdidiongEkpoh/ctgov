{{ config(materialized='table') }}

WITH versions AS (
    SELECT nct_id 
        , {{ parse_partial_date('last_update_post_date_raw') }} AS valid_from
        , record:protocolSection:statusModule:overallStatus::string AS overall_status
        , record:protocolSection:designModule:enrollmentInfo:count::int AS enrollment_count
        , record:protocolSection:designModule:enrollmentInfo:type::string AS enrollment_type
        , {{ parse_partial_date("record:protocolSection:statusModule:primaryCompletionDateStruct:date::string") }} AS primary_completion_date
        , record:protocolSection:statusModule:primaryCompletionDateStruct:type::string AS primary_completion_date_type
        , record:hasResults::boolean AS has_results
        , record_hash
        , loaded_at
    FROM {{ ref('brz_ctgov__studies') }}
    WHERE nct_id IS NOT NULL
)
, ordered AS (
    SELECT *
        , LEAD(valid_from) OVER (PARTITION BY nct_id ORDER BY valid_from, loaded_at) AS valid_to
        , LAG(overall_status) OVER (PARTITION BY nct_id ORDER BY valid_from, loaded_at) AS previous_status
    FROM versions
)
SELECT nct_id
    , valid_from
    , valid_to
    , (valid_to IS NULL) AS is_current
    , overall_status
    , previous_status
    , (previous_status IS NOT NULL AND previous_status <> overall_status) AS status_changed
    , enrollment_count
    , enrollment_type
    , primary_completion_date
    , primary_completion_date_type
    , has_results
    , record_hash
    , loaded_at
FROM ordered