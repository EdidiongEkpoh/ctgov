WITH studies AS (
    SELECT *
    FROM {{ ref('slv_ctgov__studies') }}
)
, us_sites AS (
    SELECT nct_id 
        , COUNT(*) AS us_site_count
    FROM {{ ref('slv_ctgov__locations') }}
    GROUP BY 1
)
, groups AS (
    SELECT nct_id 
        , COUNT(*) AS condition_group_count
    FROM {{ ref('slv_trials__condition_groups') }}
    GROUP BY 1
)
    SELECT s.nct_id
        , 'https://clinicaltrials.gov/study/' || s.nct_id AS study_url
        , s.brief_title

        -- status
        , s.overall_status
        , {{ label('s.overall_status') }} AS overall_status_label
        , CASE 
                WHEN s.overall_status IN ('RECRUITING', 'NOT_YET_RECRUITING', 'ACTIVE_NOT_RECRUITING', 'ENROLLING_BY_INVITATION') THEN 'Active'
                WHEN s.overall_status = 'COMPLETED' THEN 'Completed'
                WHEN s.overall_status IN ('TERMINATED', 'WITHDRAWN', 'SUSPENDED') THEN 'Stopped Early'
                ELSE 'Other / Unknown'
          END AS status_group
        
        -- design
        , s.phase_group
        , CASE s.phase_group 
                WHEN 'Early Phase 1' THEN 1
                WHEN 'Phase 1' THEN 2 
                WHEN 'Phase 1/2' THEN 3
                WHEN 'Phase 2' THEN 4
                WHEN 'Phase 2/3' THEN 5 
                WHEN 'Phase 3' THEN 6
                WHEN 'Phase 4' THEN 7
                WHEN 'Not Applicable' THEN 8
                ELSE 9
          END AS phase_sort
        , s.enrollment_count
        , s.enrollment_type
        
        -- dates
        , s.start_date
        , YEAR(s.start_date) AS start_year
        , s.primary_completion_date
        , s.primary_completion_date_type
        , s.completion_date

        -- sponsor
        , {{ sponsor_key('s.lead_sponsor_name', 's.lead_sponsor_class') }} AS sponsor_key
        , s.lead_sponsor_name
        , s.sponsor_group

        -- flags
        , s.is_fda_regulated_drug
        , s.is_fda_regulated_device
        , s.has_results
        , COALESCE(u.us_site_count, 0) > 0 AS has_us_site
        , COALESCE(u.us_site_count, 0) AS us_site_count
        , COALESCE(g.condition_group_count, 0) AS condition_group_count
    FROM studies AS s 
    LEFT JOIN us_sites AS u ON u.nct_id = s.nct_id
    LEFT JOIN groups g ON g.nct_id = s.nct_id
