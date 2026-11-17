{{ config(materialized='table') }}

SELECT v.nct_id
    , c.index AS condition_seq
    , TRIM(c.value::string) AS condition
FROM {{ ref('slv_ctgov__latest_versions') }} AS v,
    LATERAL FLATTEN(input => v.record:protocolSection:conditionsModule:conditions) AS c 
WHERE NULLIF(TRIM(c.value::string), '') IS NOT NULL