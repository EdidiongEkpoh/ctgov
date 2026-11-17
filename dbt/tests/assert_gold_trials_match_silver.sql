SELECT COUNT(*) AS missing
FROM {{ ref('slv_ctgov__studies') }} s
LEFT JOIN {{ ref('dim_trial') }} d ON d.nct_id = s.nct_id
WHERE d.nct_id IS NULL 
HAVING COUNT(*) > 0