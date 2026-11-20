SELECT nct_id
    , {{ sponsor_key('lead_sponsor_name', 'lead_sponsor_class') }} AS sponsor_key
    , primary_completion_date
    , YEAR(primary_completion_date) AS primary_completion_year
    , due_date
    , results_first_submit_date
    , results_first_post_date
    , days_to_results
    , DATEDIFF(day, due_date, results_first_submit_date) AS days_late
    
    , reporting_status
    , {{ label('reporting_status') }} AS reporting_status_label

    , iff(is_probable_act, 1, 0) AS is_probable_act
    , iff(is_probable_act AND reporting_status <> 'delay_requested', 1, 0) AS is_compliance_eligible
    , iff(t.reporting_status = 'on_time', 1, 0) AS is_on_time
    , iff(reporting_status IN ('on_time', 'late'), 1, 0) AS is_reported
    , iff(reporting_status = 'not_reported', 1, 0) AS is_not_reported
    , 1 AS trial_count
FROM {{ ref('slv_trials__results_timeliness') }} 