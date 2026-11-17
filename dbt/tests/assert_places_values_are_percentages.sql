SELECT county_fips
    , measure_id
    , data_value_type_id
    , data_value
FROM {{ ref('slv_cdc__places_county') }}
WHERE data_value < 0 OR data_value > 100