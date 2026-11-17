SELECT nct_id || '-' || location_seq AS site_id
    , nct_id
    , county_fips
    , facility
    , city
    , state 
    , zip5
    , lat
    , lon
    , site_status 
    , iff(is_active_site, 1, 0) AS is_active_site
    , iff(is_geocoded, 1, 0) AS is_geocoded 
    , 1 AS site_count
FROM {{ ref('slv_sites__county') }}