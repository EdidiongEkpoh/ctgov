WITH groups AS (
    SELECT DISTINCT condition_group
        , places_measure_id
    FROM {{ ref('condition_group_map') }}
)
, measures AS (
    SELECT DISTINCT measure_id
        , measure_name
        , measure_short_name
    FROM {{ ref('slv_cdc__places_county') }}
    WHERE is_latest_release
)
SELECT g.condition_group
    , {{ label('g.condition_group') }} AS condition_group_label
    , g.places_measure_id
    , m.measure_name AS places_measure_name
    , m.measure_short_name AS places_measure_short_name
FROM groups g 
LEFT JOIN measures m ON m.measure_id = g.places_measure_id