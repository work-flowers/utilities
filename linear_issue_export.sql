SELECT
	i.id AS issue_id,
	i.identifier,
	i.title,
	i.description,
	i.created_at,
	i.started_at,
	i.completed_at,
	t.key AS team_key,
	t.id AS team_id,
	ws.name AS status,
	ws.type AS status_type,
	i.cycle_id,
	i.estimate,
	i.priority_label AS priority,
	c.starts_at AS cycle_start,
	c.ends_at AS cycle_end,
	a.url AS slack_link
FROM linear.issue AS i
INNER JOIN linear.team AS t
	ON i.team_id = t.id
INNER JOIN linear.workflow_state AS ws
	ON i.state_id = ws.id
LEFT JOIN linear.cycle AS c
	ON i.cycle_id = c.id
LEFT JOIN linear.attachment AS a
	ON i.id = a.issue_id
	AND a._fivetran_deleted IS FALSE
	AND a.source_type = 'slack'
WHERE i._fivetran_deleted IS FALSE
QUALIFY ROW_NUMBER() OVER(
	PARTITION BY i.id 
	ORDER BY a.created_at DESC
) = 1