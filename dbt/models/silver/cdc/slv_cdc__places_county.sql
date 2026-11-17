{{ config(materialized='table') }}

WITH typed AS (
    SELECT release
        , LPAD(location_id, 5, '0') AS county_fips
        , record:stateabbr::string AS state_abbr
        , record:statedesc::string AS state_name
        , record:locationname::string AS county_name
        , TRY_TO_NUMBER(record:year::string) AS data_year
        , record:cateogory::string AS category_id
        , measure_id
        , record:measure::string AS measure_name
        , record:short_question_text::string AS measure_short_name
        , data_value_type_id
        , TRY_TO_DOUBLE(record:data_value::string) AS data_value
        , TRY_TO_DOUBLE(record:low_confidence_limit::string) AS low_confidence_limit
        , TRY_TO_DOUBLE(record:high_confidence_limit::string) AS high_confidence_limit
        , TRY_TO_NUMBER(record:totalpopulation::string) AS total_population
        , TRY_TO_NUMBER(record:totalpop18plus::string) AS total_pop_18plus
        , loaded_at
    FROM {{ ref('brz_cdc__places_county') }}
)
SELECT *
    , (release = MAX(release) OVER ()) AS is_latest_release
FROM typed
QUALIFY ROW_NUMBER() OVER (
    partition by release, county_fips, measure_id, data_value_type_id
    ORDER BY loaded_at DESC
) = 1
