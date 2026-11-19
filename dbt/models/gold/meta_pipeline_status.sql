WITH sites AS (
    SELECT COUNT_IF(zip5 IS NOT NULL) AS us_sites_with_zip
        , COUNT_IF(zip5 IS NOT NULL AND is_geocoded) AS us_sites_geocoded
    FROM {{ ref('slv_sites__county') }}
)
, stops AS (
    SELECT COUNT(*) AS stopped_trials
        , COUNT_IF(reason_category NOT IN ('other', 'unspecified')) AS stopped_trials_classified
    FROM {{ ref('slv_trials__termination_reasons') }}
)
SELECT CURRENT_TIMESTAMP() AS gold_built_at
    , (SELECT MAX(loaded_at) FROM {{ ref('slv_ctgov__latest_versions') }}) AS last_ctgov_load_at
    , (SELECT MAX(release) FROM {{ ref('slv_cdc__places_county') }}) AS places_release
    , (SELECT COUNT(*) FROM {{ ref('slv_ctgov__studies') }}) AS studies_in_scope
    , (SELECT COUNT(*) FROM {{ ref('slv_trials__results_timeliness') }}) AS trials_results_due
    , sites.us_sites_with_zip
    , sites.us_sites_geocoded
    , sites.us_sites_geocoded / NULLIF(sites.us_sites_with_zip, 0) AS geocoded_share
    , stops.stopped_trials
    , stops.stopped_trials_classified / NULLIF(stops.stopped_trials, 0) AS stop_reason_classified_share
FROM sites
CROSS JOIN stops