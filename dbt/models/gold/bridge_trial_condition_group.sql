SELECT nct_id
    , condition_group
FROM {{ ref('slv_trials__condition_groups') }}