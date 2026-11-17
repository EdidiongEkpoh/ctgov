WITH groups AS (
    SELECT DISTINCT condition_group
        , places_measure_id
    FROM {{ ref('condition_group_map') }}
)
, burden AS (
    SELECT county_fips
        , measure_id
        , MAX(iff(data_value_type_id = 'AgeAdjPrv', data_value, NULL)) AS prevalence_age_adj_pct
        , MAX(iff(data_value_type_id = 'CrdPrv', data_value, NULL)) AS prevalence_crude_pct
        , MAX(total_pop_18plus) AS adult_population
    FROM {{ ref('slv_cdc__places_county') }}
    WHERE is_latest_release
    GROUP BY 1, 2
)
, active_sites AS (
    SELECT s.county_fips
        , g.condition_group
        , COUNT(DISTINCT s.nct_id || '-' || s.location_seq) AS active_sites
        , COUNT(DISTINCT s.nct_id) AS active_trials
    FROM {{ ref('slv_sites__county') }} s
    JOIN {{ ref('slv_trials__condition_groups') }} g ON g.nct_id = s.nct_id
    WHERE s.is_active_site
    GROUP BY 1, 2
)
, combined AS (
    SELECT b.county_fips
        , g.condition_group
        , g.places_measure_id
        , b.adult_population
        , b.prevalence_age_adj_pct
        , b.prevalence_crude_pct
        , ROUND(b.prevalence_crude_pct / 100 * b.adult_population) AS est_adults_affected
        , COALESCE(a.active_sites, 0) AS active_sites
        , COALESCE(a.active_trials, 0) AS active_trials
    FROM groups g
    JOIN burden b ON b.measure_id = g.places_measure_id
    LEFT JOIN active_sites a ON a.county_fips = b.county_fips
        AND a.condition_group = g.condition_group
)
, rated AS (
    SELECT *
        , active_sites / NULLIF(adult_population, 0) * 100000 AS sites_per_100k_adults
        , active_sites / NULLIF(est_adults_affected, 0) * 10000 AS sites_per_10k_affected
    FROM combined
)
, ranked AS (
    SELECT *
        , iff(prevalence_age_adj_pct IS NULL, NULL, PERCENT_RANK() OVER (PARTITION BY condition_group, prevalence_age_adj_pct IS NULL ORDER BY prevalence_age_adj_pct)) AS burden_pctile
        , iff(sites_per_10k_affected IS NULL, NULL, PERCENT_RANK() OVER (PARTITION BY condition_group, sites_per_10k_affected IS NULL ORDER BY sites_per_10k_affected)) AS access_pctile
    FROM rated
)
SELECT county_fips
    , condition_group
    , places_measure_id
    , adult_population
    , prevalence_age_adj_pct
    , prevalence_crude_pct
    , est_adults_affected
    , active_sites
    , active_trials
    , sites_per_100k_adults
    , sites_per_10k_affected
    , burden_pctile
    , access_pctile
    , burden_pctile - access_pctile AS gap_score
    , CASE
            WHEN burden_pctile IS NULL OR access_pctile IS NULL THEN 'Insufficient Data'
            WHEN burden_pctile >= 0.75 AND active_sites = 0 THEN 'High burden, no active sites'
            WHEN burden_pctile >= 0.75 AND access_pctile = 0.25 THEN 'High burden, low access'
            WHEN burden_pctile < 0.25 AND access_pctile >= 0.75 THEN 'Low burden, high access'
            ELSE 'In Between'
      END AS gap_category
    , iff(adult_population < 10000, 1, 0) AS is_small_county
FROM ranked