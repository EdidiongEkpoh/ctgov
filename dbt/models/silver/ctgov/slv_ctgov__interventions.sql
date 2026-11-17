{{ config(materialized='table') }}

SELECT v.nct_id 
    , i.index AS intervention_seq 
    , i.value:type::string AS intervention_type
    , i.value:name::string AS intervention_name
FROM {{ ref('slv_ctgov__latest_versions') }} AS v,
    LATERAL FLATTEN(input => v.record:protocolSection:armsInterventionsModule:interventions) AS i