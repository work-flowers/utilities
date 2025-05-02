
WITH task_latest AS (
	SELECT *
	FROM harvest.task
	WHERE
		1 = 1
		AND _fivetran_deleted IS FALSE
	QUALIFY ROW_NUMBER() OVER(PARTITION BY id ORDER BY  updated_at DESC) = 1

),

client_latest AS (
	SELECT *
	FROM harvest.client
	QUALIFY ROW_NUMBER() OVER(PARTITION BY id ORDER BY  updated_at DESC) = 1
),

te_latest AS (
	SELECT
		te.id AS time_entry_id,
		cl.name AS client,
		tl.name AS task,
		te.rounded_hours,
		JSON_VALUE(te.external_reference, '$.id') AS linear_identifier
	FROM harvest.time_entry AS te
	INNER JOIN task_latest AS tl
		ON te.task_id = tl.id
	INNER JOIN client_latest AS cl
		ON te.client_id = cl.id
	WHERE
		1 = 1
		AND te._fivetran_deleted IS FALSE
	QUALIFY ROW_NUMBER() OVER (PARTITION BY te.id ORDER BY te.updated_at DESC) = 1
)

SELECT
	h.*,
	i.estimate,
	i.title,
	ws.name AS issue_status,
	DATE(i.created_at) AS issue_created,
	DATE(i.started_at) AS issue_started,
	DATE(i.completed_at) AS issue_completed

FROM te_latest AS h
LEFT JOIN linear.issue AS i
	ON h.linear_identifier = i.identifier
	AND i._fivetran_deleted IS FALSE
LEFT JOIN linear.workflow_state AS ws
	ON i.state_id = ws.id




