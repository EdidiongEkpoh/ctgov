SELECT county_fips
    , ANY_VALUE(county_name) AS county_name
    , ANY_VALUE(state_abbr) AS state_abbr
    , ANY_VALUE(state_name) AS state_name
    , ANY_VALUE(county_name) || ', ' || ANY_VALUE(state_abbr) AS county_label
    , MAX(total_population) AS total_population
    , MAX(total_pop_18plus) AS adult_population
    , ANY_VALUE(release) AS places_release
FROM {{ ref('slv_cdc__places_county') }}
WHERE is_latest_release
GROUP BY 1