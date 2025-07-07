SELECT
	i.id AS issue_id,
	DATE(i.created_at) AS created_date,
	DATE(i.due_date) AS due_date,
	DATE(i.completed_at) AS completed_date,
	i.created_at,
	ws.name	AS status,
	c.number AS cycle_number,
	DATE(c.starts_at) AS cycle_start_date,
	DATE(c.ends_at) AS cycle_end,
FROM linear.issue AS i
INNER JOIN linear.team AS t
	ON i.team_id = t.id
	AND t.key = 'WFOF' -- Ordinary Folk team
INNER JOIN linear.workflow_state AS ws
	ON i.state_id = ws.id
LEFT JOIN linear.cycle AS c
	ON i.cycle_id = c.id
WHERE
	1 = 1
	AND i._fivetran_deleted IS FALSE
	AND (ws.type = 'triage' OR c.id IS NOT NULL)