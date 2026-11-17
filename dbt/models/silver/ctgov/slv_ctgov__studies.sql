{{ config(materialized='table') }}

WITH src AS (
    SELECT DISTINCT nct_id   
        , record:protocolSection AS p  
        , record:hasResults::boolean AS has_results 
        , last_update_post_date
        , versions_stored
        , loaded_at
    FROM {{ ref('slv_ctgov__latest_versions') }}
)
, typed AS (
    SELECT nct_id 
        -- identification
        , p:identificationModule:briefTitle::string AS brief_title
        , p:identificationModule:officialTitle::string AS official_title

        -- status
        , p:statusModule:overallStatus::string AS overall_status
        , NULLIF(TRIM(p:statusModule:whyStopped::string), '') AS why_stopped

        -- design
        , p:designModule:studyType::string AS study_type
        , ARRAY_TO_STRING(p:designModule:phases, '/') AS phases_raw
        , p:designModule:enrollmentInfo:count::int AS enrollment_count
        , p:designModule:enrollmentInfo:type::string AS enrollment_type

        -- key dates
        , {{ parse_partial_date("p:statusModule:startDateStruct:date::string") }} AS start_date
        , p:statusModule:startDateStruct:type::string AS start_date_type
        , {{ parse_partial_date("p:statusModule:completionDateStruct:date::string") }} AS completion_date
        , p:statusModule:completionDateStruct:type::string AS completion_date_type
        , {{ parse_partial_date("p:statusModule:primaryCompletionDateStruct:date::string") }} AS primary_completion_date
        , p:statusModule:primaryCompletionDateStruct:type::string AS primary_completion_date_type
        , {{ parse_partial_date("p:statusModule:studyFirstSubmitDate::string") }} AS study_first_submit_date
        , {{ parse_partial_date("p:statusModule:resultsFirstSubmitDate::string") }} AS results_first_submit_date
        , {{ parse_partial_date("p:statusModule:resultsFirstPostDateStruct:date::string") }} AS results_first_post_date
        , {{ parse_partial_date("p:statusModule:dispFirstSubmitDate::string") }} AS delay_request_submit_date
        , p:statusModule:primaryCompletionDateStruct:date::string AS primary_completion_date_raw
        , last_update_post_date

        -- sponsor
        , p:sponsorCollaboratorsModule:leadSponsor:name::string AS lead_sponsor_name
        , p:sponsorCollaboratorsModule:leadSponsor:class::string AS lead_sponsor_class
        
        -- oversight
        , COALESCE(p:oversightModule:isFdaRegulatedDrug::boolean, FALSE) AS is_fda_regulated_drug
        , COALESCE(p:oversightModule:isFdaRegulatedDevice::boolean, FALSE) AS is_fda_regulated_device

        -- results
        , COALESCE(has_results, FALSE) AS has_results
        
        , versions_stored
        , loaded_at
    
    FROM src
)
SELECT t.*
    , CASE 
        WHEN phases_raw = 'EARLY_PHASE1' THEN 'Early Phase 1'
        WHEN phases_raw = 'PHASE1' THEN 'Phase 1'
        WHEN phases_raw = 'PHASE1/PHASE2' THEN 'Phase 1/2'
        WHEN phases_raw = 'PHASE2' THEN 'Phase 2'
        WHEN phases_raw = 'PHASE2/PHASE3' THEN 'Phase 2/3'
        WHEN phases_raw = 'PHASE3' THEN 'Phase 3'
        WHEN phases_raw = 'PHASE4' THEN 'Phase 4'
        WHEN phases_raw = 'NA' THEN 'Not Applicable'
        ELSE CASE WHEN phases_raw IS NULL OR phases_raw = '' THEN 'Not Reported' ELSE 'Other' END
      END AS phase_group
    , COALESCE(s.sponsor_group, 'Academic & other') AS sponsor_group
FROM typed t
LEFT JOIN {{ ref('sponsor_class_map') }} s ON t.lead_sponsor_class = s.sponsor_class 

QUALIFY ROW_NUMBER() OVER (PARTITION BY nct_id ORDER BY last_update_post_date DESC, loaded_at) = 1