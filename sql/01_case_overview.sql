-- Learning exercise: SELECT chooses fields, GROUP BY forms groups,
-- COUNT(*) counts rows in each group. These are inventory queries.
-- Case eligibility and outcome mappings will be validated in the next lesson.
BEGIN READ ONLY;

SELECT institution_id, count(*) AS cases
FROM efrm.case_master
GROUP BY institution_id
ORDER BY institution_id;

SELECT institution_id, status, decision_code, approval_status, count(*) AS cases
FROM efrm.case_master
GROUP BY institution_id, status, decision_code, approval_status
ORDER BY institution_id, status, decision_code, approval_status;

-- A numeric alert ID alone is not enough: its source table is also needed.
SELECT c.institution_id, m.alert_type, m.alert_source_table, count(*) AS mappings
FROM efrm.case_alert_mapping AS m
JOIN efrm.case_master AS c ON c.case_id = m.case_id
GROUP BY c.institution_id, m.alert_type, m.alert_source_table
ORDER BY c.institution_id, m.alert_type, m.alert_source_table;

SELECT config_master_id, decision_code, decision_name, alert_type, requires_approval
FROM efrm.case_decision_master
ORDER BY config_master_id, decision_code;

-- Alert-level decisions are distinct from the final decision on case_master.
SELECT c.institution_id, m.alert_type, m.decision_code, count(*) AS mappings
FROM efrm.case_alert_mapping AS m
JOIN efrm.case_master AS c ON c.case_id = m.case_id
GROUP BY c.institution_id, m.alert_type, m.decision_code
ORDER BY c.institution_id, m.alert_type, m.decision_code;

COMMIT;
