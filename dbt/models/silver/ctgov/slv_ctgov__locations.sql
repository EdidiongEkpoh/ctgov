{{ config(materialized='table') }}

SELECT v.nct_id
    , loc.index AS location_seq
    , loc.value:facility::string AS facility
    , loc.value:city::string AS city
    , loc.value:state::string AS state 
    , loc.value:zip::string AS zip_raw
    , loc.value:country::string AS country
    , loc.value:status::string AS site_status
    , loc.value:geoPoint:lat::float AS lat
    , loc.value:geoPoint:lon::float AS lon
    , (loc.value:country::string = 'United States') AS is_us
    , CASE
        WHEN loc.value:country::string = 'United States'
            AND REGEXP_LIKE(loc.value:zip::string, '^[0-9]{5}.*')
            THEN LEFT(loc.value:zip::string, 5)
      END AS zip5
FROM {{ ref('slv_ctgov__latest_versions') }} AS v,
    LATERAL FLATTEN(input => v.record:protocolSection:contactsLocationsModule:locations) AS loc