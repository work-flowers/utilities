-- unnests all email addresses into a view

DROP VIEW IF EXISTS attio.email_addresses;
CREATE VIEW attio.email_addresses AS 

SELECT
  t.record_id,
  JSON_VALUE(elem, '$.email_address') AS email_address,
  JSON_VALUE(elem, '$.email_domain') AS domain 
FROM attio.record_value  AS t,
  UNNEST(JSON_EXTRACT_ARRAY(t.value)) AS elem
WHERE
	1 = 1
	AND t.name = 'email_addresses';

-- Unnests company info

DROP VIEW IF EXISTS attio.companies;
CREATE VIEW attio.companies AS(

	SELECT
		rv.record_id AS company_id,
	  	MAX(
			CASE 
				WHEN rv.name = 'name' 
	  			THEN JSON_VALUE(elem, '$.value')
	  			END
		) AS company_name,
		MAX(
			CASE 
				WHEN rv.name = 'domains' 
				THEN JSON_VALUE(elem, '$.domain')
				END
		) AS domain

	FROM attio.object AS obj
	INNER JOIN attio.record_value AS rv
    	ON rv.record_object_id = obj.id
	CROSS JOIN UNNEST(JSON_EXTRACT_ARRAY(rv.value)) AS elem
	WHERE
		1 = 1
		AND obj.singular_noun = 'Company'
	GROUP BY 1
);




