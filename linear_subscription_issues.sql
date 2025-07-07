-- Select issue details along with related workflow state and cycle info for Ordinary Folk team issues

SELECT
	i.id AS issue_id,                      -- Unique identifier for the issue
	DATE(i.created_at) AS created_date,    -- Date the issue was created (date only, no time)
	DATE(i.due_date) AS due_date,          -- Due date for the issue (if set)
	DATE(i.completed_at) AS completed_date,-- Date the issue was completed (if completed)
	i.created_at,                          -- Full timestamp of when the issue was created
	ws.name AS status,                     -- Current workflow status (e.g., Backlog, In Progress, Done)
	c.number AS cycle_number,              -- Linear cycle number (sprint or iteration, if any)
	DATE(c.starts_at) AS cycle_start_date, -- Start date of the cycle containing this issue
	DATE(c.ends_at) AS cycle_end           -- End date of the cycle containing this issue
FROM linear.issue AS i

-- Only include issues belonging to the Ordinary Folk team (team key = 'WFOF')
INNER JOIN linear.team AS t
	ON i.team_id = t.id
	AND t.key = 'WFOF' -- Ordinary Folk team

-- Join to get the workflow status for each issue
INNER JOIN linear.workflow_state AS ws
	ON i.state_id = ws.id

-- Optionally join to cycle table, if the issue is assigned to a cycle
LEFT JOIN linear.cycle AS c
	ON i.cycle_id = c.id

WHERE
	1 = 1                                 -- Placeholder for easier extension of WHERE clause
	-- Only include issues that are either in a triage state OR assigned to a cycle	
	AND i._fivetran_deleted IS FALSE      -- Exclude deleted issues (using Fivetran soft-delete flag)
	AND (ws.type = 'triage' OR c.id IS NOT NULL) 
;