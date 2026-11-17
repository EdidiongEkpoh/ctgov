{% set act_effective_date = "'2017-01-18'::date" %}
{% set grace_days = 30 %}

WITH studies AS (
    SELECT *
    FROM {{ ref('slv_ctgov__studies') }}
)
, us_sites AS (
    SELECT DISTINCT nct_id
    FROM {{ ref('slv_ctgov__locations') }}
    WHERE is_us
)
, due AS (
    SELECT s.nct_id
        , s.lead_sponsor_name
        , s.lead_sponsor_class
        , s.sponsor_group
        , s.phase_group
        , s.overall_status
        , s.is_fda_regulated_drug
        , s.is_fda_regulated_device
        , (u.nct_id IS NOT NULL) AS has_us_site
        , s.primary_completion_date
        , s.primary_completion_date_raw
        , DATEADD(year, 1, s.primary_completion_date) AS due_date
        , s.results_first_submit_date
        , s.results_first_post_date
        , s.delay_request_submit_date
        , s.has_results
    FROM studies s
    LEFT JOIN us_sites AS u ON u.nct_id = s.nct_id 
    WHERE s.study_type = 'INTERVENTIONAL'
        AND s.primary_completion_date_type = 'ACTUAL'
        AND s.primary_completion_date IS NOT NULL 
        AND DATEADD(day, {{ grace_days }}, DATEADD(year, 1, s.primary_completion_date)) <= CURRENT_DATE()
)
SELECT *
    , (
        phase_group NOT IN ('Early Phase 1', 'Phase 1')
        AND (is_fda_regulated_drug OR is_fda_regulated_device)
        AND has_us_site
        AND primary_completion_date >= {{ act_effective_date }}
    ) AS is_probable_act
    , DATEDIFF(day, primary_completion_date, results_first_submit_date) AS days_to_results
    , CASE
            WHEN results_first_submit_date <= due_date THEN 'on_time'
            WHEN delay_request_submit_date IS NOT NULL THEN 'delay_requested'
            WHEN results_first_submit_date IS NOT NULL THEN 'late'
            ELSE 'not_reported'
      END AS reporting_status
FROM due