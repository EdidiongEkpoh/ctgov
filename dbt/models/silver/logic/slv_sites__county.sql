WITH crosswalk AS (
    SELECT LPAD(zip::string, 5, '0') AS zip5
        , LPAD(county_fips::string, 5, '0') AS county_fips
        , res_ratio
    FROM {{ ref('zip_county_crosswalk') }}
    QUALIFY ROW_NUMBER() OVER (PARTITION BY LPAD(zip::string, 5, '0') ORDER BY res_ratio DESC, county_fips) = 1
)
, sites AS (
    SELECT l.nct_id
        , l.location_seq
        , l.facility
        , l.city
        , l.state
        , l.zip5
        , l.site_status
        , l.lat
        , l.lon 
        , s.overall_status 
    FROM {{ ref('slv_ctgov__locations') }} l
    JOIN {{ ref('slv_ctgov__studies') }} s ON l.nct_id = s.nct_id
    WHERE l.is_us
)
SELECT s.*
    , c.county_fips
    , (c.county_fips IS NOT NULL) AS is_geocoded
    , (
        COALESCE(s.site_status, s.overall_status) IN ('RECRUITING', 'NOT_YET_RECRUITING', 'ACTIVE_NOT_RECRUITING', 'ENROLLING_BY_INVITATION')
        AND s.overall_status IN ('RECRUITING', 'NOT_YET_RECRUITING', 'ACTIVE_NOT_RECRUITING', 'ENROLLING_BY_INVITATION')
    ) AS is_active_site 
FROM sites s 
LEFT JOIN crosswalk c ON s.zip5 = c.zip5