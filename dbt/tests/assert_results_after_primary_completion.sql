{{ config(severity='warn') }}

SELECT nct_id
    , primary_completion_date
    , results_first_submit_date
FROM {{ ref('slv_trials__results_timeliness') }}
WHERE results_first_submit_date < primary_completion_date