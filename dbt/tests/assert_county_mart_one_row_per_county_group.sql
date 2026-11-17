SELECT county_fips
    , condition_group
    , COUNT(*) AS n 
FROM {{ ref('mart_county_burden_vs_sites') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1