SELECT r.nct_id
    , {{ sponsor_key('r.lead_sponsor_name', 's.lead_sponsor_class') }} AS sponsor_key
    , r.overall_status
    , {{ label('r.overall_status') }} AS overall_status_label
    , r.reason_category
    , {{ label('r.reason_category') }} AS reason_label
    , r.why_stopped_raw
    , r.start_date
    , r.stop_date
    , YEAR(r.stop_date) AS stop_year
    , r.months_running

    , r.enrollment_count
    , r.enrollment_type
    , iff(r.enrollment_type = 'ACTUAL', r.enrollment_count, NULL) AS participants_enrolled
    , iff(r.reason_category = 'unspecified', 0, 1) has_reason
    , 1 AS trial_count
FROM {{ ref('slv_trials__termination_reasons') }} r
JOIN {{ ref('slv_ctgov__studies') }} s ON s.nct_id = r.nct_id