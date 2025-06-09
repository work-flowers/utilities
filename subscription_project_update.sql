WITH sub AS (
	SELECT *
	FROM stripe.subscription_history
	-- we only want the most recent row for each subscription_id, since 
	-- stripe.subscription_history is a versioned history table
	QUALIFY ROW_NUMBER() OVER(PARTITION BY id ORDER BY _fivetran_start DESC) = 1
),

main AS (
	SELECT
		i.identifier AS `Linear Issue ID`,
		ws.name AS `Issue Status`,
		i.estimate AS `Points Assigned`,
		DATE(i.created_at) AS `Created At`,
		DATE(i.started_at) AS `Started At`,
		DATE(i.completed_at) AS `Completed At`
	FROM sub
	
	-- find subscription line items
	INNER JOIN stripe.subscription_item AS si
		ON sub.id = si.subscription_id
	
	-- find Stripe prices
	INNER JOIN stripe.price AS px
		ON si.plan_id = px.id
	
	-- find Stripe product to get monthly_points from metadata
	INNER JOIN stripe.product AS pr
		ON px.product_id = pr.id
	
	-- find Stripe customer
	INNER JOIN stripe.customer AS cus
		ON sub.customer_id = cus.id
	
	-- link customer to attio person record id based on email address
	INNER JOIN attio.email_addresses AS em
		ON cus.email = em.email_address
	
	-- link attio person record to company record
	INNER JOIN attio.companies AS com
		ON em.domain = com.domain
	
	-- link attio company record id to linear customer id
	INNER JOIN google_sheets.company_ids AS ci
		ON com.company_id = ci.attio_company_id
	
	-- link to Linear project id from Linear customer id
	INNER JOIN google_sheets.project_ids AS proj
		ON ci.linear_customer_id = proj.linear_customer_id
	
	-- find any linear issues tied to linear project and within the current Stripe billing cycle
	INNER JOIN linear.issue AS i
		ON proj.linear_project_id = i.project_id		
	
	-- finally, pull Linear status name values
	INNER JOIN linear.workflow_state AS ws
		ON i.state_id = ws.id
	WHERE
		1 = 1
		AND sub.status = 'active'
		AND CURRENT_DATE BETWEEN DATE(sub.current_period_start) AND DATE(sub.current_period_end) 
		AND (
			DATE(COALESCE(i.completed_at, i.started_at, i.created_at)) BETWEEN DATE(sub.current_period_start) AND DATE(sub.current_period_end) 
			OR ws.type = 'started'
		)
)

SELECT * 
FROM main
ORDER BY 2, 3 DESC

-- SELECT 
-- 	`Issue Status`,
-- 	SUM(`Points Assigned`) AS `Points Assigned`
-- FROM main
-- GROUP BY 1
