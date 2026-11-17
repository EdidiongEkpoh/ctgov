SELECT nct_id
    , overall_status
    , why_stopped AS why_stopped_raw
    , {{ classify_why_stopped('why_stopped') }} AS reason_category
    , phase_group
    , sponsor_group
    , lead_sponsor_name
    , enrollment_count
    , enrollment_type
    , start_date
    , COALESCE(completion_date, primary_completion_date) AS stop_date
    , DATEDIFF(month, start_date, COALESCE(completion_date, primary_completion_date)) AS months_running
FROM {{ ref('slv_ctgov__studies') }} 
WHERE overall_status IN ('TERMINATED', 'WITHDRAWN', 'SUSPENDED')