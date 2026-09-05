-- Lesson 2, first join: a case can contain several alerts from different sources.
-- Case 41 is a confirmed-fraud example used only to learn the database links.
SELECT c.case_id,
       c.decision_code AS case_decision,
       m.id AS mapping_id,
       m.alert_id,
       m.alert_type,
       m.alert_source_table
FROM efrm.case_master AS c
LEFT JOIN efrm.case_alert_mapping AS m
    ON m.case_id = c.case_id
WHERE c.institution_id = 'KANJI'
  AND c.case_id = 41
ORDER BY m.id;
