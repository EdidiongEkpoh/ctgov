SELECT DISTINCT m.nct_id 
    , g.condition_group
    , g.places_measure_id
FROM {{ ref('slv_ctgov__condition_mesh') }} m 
JOIN {{ ref('condition_group_map') }} g ON LOWER(m.mesh_term) = LOWER(g.mesh_term)