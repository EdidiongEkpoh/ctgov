SELECT record_hash AS status_version_id
    , nct_id 
    , valid_from 
    , valid_to
    , iff(is_current, 1, 0) AS is_current 
    , overall_status
    , {{ label('overall_status') }} AS overall_status_label
    , previous_status
    , {{ label('previous_status') }} AS previous_status_label
    , iff(status_changed, 1, 0) AS is_status_change
    , enrollment_count
    , enrollment_type
    , primary_completion_date
    , primary_completion_date_type
    , iff(has_results, 1, 0) AS has_results
    , ROW_NUMBER() OVER (PARTITION BY nct_id ORDER BY valid_from, loaded_at) AS version_number
FROM {{ ref('slv_ctgov__study_status_history') }}