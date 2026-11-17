SELECT county_fips
    , condition_group
    , burden_pctile
    , access_pctile
    , gap_score
FROM {{ ref('mart_county_burden_vs_sites') }}
WHERE burden_pctile NOT BETWEEN 0 AND 1 
    OR access_pctile NOT BETWEEN 0 AND 1
    OR gap_score NOT BETWEEN -1 AND 1