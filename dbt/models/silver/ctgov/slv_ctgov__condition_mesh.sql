{{ config(materialized='table') }}

WITH mesh AS (
    SELECT v.nct_id
        , m.value:id::string AS mesh_id
        , m.value:term::string AS mesh_term
        , 'mesh' AS term_source
    FROM {{ ref('slv_ctgov__latest_versions') }} AS v,
        LATERAL FLATTEN(input => v.record:derivedSection:conditionBrowseModule:meshes) AS m 
)
, ancestors AS (
    SELECT v.nct_id
        , a.value:id::string AS mesh_id
        , a.value:term::string AS mesh_term
        , 'ancestor' AS term_source
    FROM {{ ref('slv_ctgov__latest_versions') }} AS v,
        LATERAL FLATTEN(input => v.record:derivedSection:conditionBrowseModule:ancestors) AS a 
)

SELECT *
FROM mesh
UNION
SELECT *
FROM ancestors