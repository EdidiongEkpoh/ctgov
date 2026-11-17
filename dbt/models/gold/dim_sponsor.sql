WITH sponsors AS (
    SELECT {{ sponsor_key('lead_sponsor_name', 'lead_sponsor_class') }} AS sponsor_key
        , lead_sponsor_name
        , lead_sponsor_class
        , sponsor_group
        , nct_id
    FROM {{ ref('slv_ctgov__studies') }}
)
SELECT sponsor_key
    , ANY_VALUE(lead_sponsor_name) AS sponsor_name
    , ANY_VALUE(lead_sponsor_class) AS sponsor_class
    , ANY_VALUE(sponsor_group) AS sponsor_group
    , COUNT(DISTINCT nct_id) AS trial_count
FROM sponsors
GROUP BY 1