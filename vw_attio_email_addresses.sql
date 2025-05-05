-- unnests all email addresses into a view

DROP VIEW IF EXISTS attio.email_addresses;
CREATE VIEW attio.email_addresses AS 

SELECT
  t.record_id,
  JSON_VALUE(elem, '$.email_address') AS email_address
FROM attio.record_value  AS t,
  UNNEST(JSON_EXTRACT_ARRAY(t.value)) AS elem
WHERE
	1 = 1
	AND t.name = 'email_addresses';