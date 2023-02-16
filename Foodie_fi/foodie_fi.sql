-- SQL Challenge: FOODIE FI APP SUBSCRIPTIONS

-- A: Customer journey
SELECT
	s.customer_id,
	GROUP_CONCAT(p.plan_name SEPARATOR ' -> ') as journey,
	GROUP_CONCAT(s.start_date SEPARATOR ' -> ') as time_line
FROM subscriptions s
LEFT JOIN plans p
	ON s.plan_id = p.plan_id
GROUP BY s.customer_id;

-- B: DA questions
-- Q1:
SELECT
	p.plan_name,
	COUNT(DISTINCT s.customer_id) as num_customer
FROM subscriptions s
LEFT JOIN 
	plans p ON s.plan_id = p.plan_id
GROUP BY 
	s.plan_id
UNION ALL
SELECT 
	'TOTAL',
	COUNT(customer_id)
FROM subscriptions
UNION ALL
SELECT 
	'TOTAL DISTINCT',
	COUNT(DISTINCT customer_id)
FROM subscriptions;

-- Q2:
SELECT
	MONTH(start_date) AS month,
	COUNT(DISTINCT customer_id) AS num_customer
FROM subscriptions
WHERE plan_id = 0
GROUP BY 1;

-- Q3:
SELECT
	s.plan_id,
	p.plan_name,
	COUNT(DISTINCT s.customer_id) AS event_2020,
	COUNT(DISTINCT CASE WHEN s.start_date >= '2021-01-01' THEN s.customer_id ELSE NULL END) AS event_2021
FROM subscriptions s
RIGHT JOIN 
	plans p ON s.plan_id = p.plan_id
GROUP BY 1;

-- Q4:
SELECT
	COUNT(DISTINCT customer_id) AS churn_count,
	ROUND(COUNT(DISTINCT customer_id)/(SELECT COUNT(DISTINCT customer_id) FROM subscriptions)*100,1) AS churn_pct
FROM subscriptions
WHERE plan_id = 4;

-- Q5:

WITH ranking AS (
SELECT
	plan_id,
	customer_id,
	start_date,
	ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY start_date) AS time_rank
FROM subscriptions
)
SELECT
	COUNT(DISTINCT customer_id) AS churn_after_trial_count,
	ROUND(COUNT(DISTINCT customer_id)/(SELECT COUNT(DISTINCT customer_id) FROM subscriptions)*100,1) AS churn_after_trial_pct
FROM ranking
WHERE 
	plan_id = 4 AND 
	time_rank = 2;

--Q6:

WITH ranking AS (
SELECT
	plan_id,
	customer_id,
	start_date,
	ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY start_date) AS time_rank
FROM subscriptions)

SELECT
	p.plan_name,
	COUNT(DISTINCT r.customer_id) AS plan_after_trial_count,
	ROUND(COUNT(DISTINCT r.customer_id)/(SELECT COUNT(DISTINCT customer_id) FROM subscriptions)*100,1) AS plan_after_trial_pct
FROM ranking r
LEFT JOIN 
	plans p ON r.plan_id = p.plan_id
WHERE 
	r.plan_id <> 4 AND 
	r.time_rank = 2
GROUP BY 1
ORDER BY 2 DESC;

-- Q7:

-- Q8:
SELECT
	p.plan_name,
	COUNT(DISTINCT s.customer_id) as num_customer
FROM subscriptions s
LEFT JOIN 
	plans p ON s.plan_id = p.plan_id
WHERE 
	p.plan_name = 'pro annual' AND
	YEAR(s.start_date) = '2020';

-- Q9:
SELECT
	COUNT(DISTINCT s.customer_id) AS pro_annual_customer,
	ROUND(AVG(DATEDIFF(start_date,join_date))) AS avg_days_to_upgrade
FROM subscriptions s
LEFT JOIN
	(SELECT
		MIN(start_date) as join_date,
		customer_id
	FROM subscriptions
	GROUP BY 2) AS j 
	ON s.customer_id = j.customer_id
WHERE plan_id = 3;

--Q10
WITH cte AS (
SELECT
	s.customer_id AS pro_annual_customer,
	DATEDIFF(start_date,join_date) AS days_to_upgrade,
	FLOOR(DATEDIFF(start_date,join_date)/30) AS bucket
FROM subscriptions s
LEFT JOIN
	(SELECT 
		MIN(start_date) as join_date,
		customer_id
	FROM subscriptions
	GROUP BY 2) AS j 
	ON s.customer_id = j.customer_id
WHERE plan_id = 3
)
SELECT 
	CONCAT(bucket*30, '-', (bucket * 30 - 1)+30, ' days') as days_to_upgrade_range, 
	COUNT( DISTINCT pro_annual_customer) as num_customer
FROM  cte
GROUP BY bucket;

-- Q11:

SELECT
	COUNT(DISTINCT s.customer_id) AS downgraded_customer
FROM subscriptions s
LEFT JOIN
	(SELECT 
		start_date,
		customer_id
	FROM subscriptions
	WHERE plan_id = 2) AS j 
	ON j.customer_id = s.customer_id
WHERE 
	s.plan_id = 1 AND
	s.start_date > j.start_date AND
	YEAR(s.start_date) = '2020';


-- C: Challenge Payment Question
WITH info AS (
WITH RECURSIVE cte AS (
	SELECT
		s.customer_id,
		s.plan_id,
		p.plan_name,
		s.start_date as payment_date,
		CASE WHEN
			LEAD(s.start_date) OVER (PARTITION BY s.customer_id ORDER BY s.start_date) IS NULL THEN '2020-12-31'
			ELSE LEAD(s.start_date) OVER (PARTITION BY s.customer_id ORDER BY s.start_date)
		END AS last_date,
		p.price as amount
	FROM subscriptions s
	LEFT JOIN 
		plans p ON s.plan_id = p.plan_id
	WHERE 
		p.plan_name <> 'trial' AND
		YEAR(start_date) = '2020'	
	UNION ALL
	SELECT 
	    customer_id,
	    plan_id,
	    plan_name,
	    DATE_ADD(payment_date, INTERVAL 1 MONTH) AS payment_date,
	    last_date,
	    amount
	FROM cte
	WHERE DATE_ADD(payment_date, INTERVAL 1 MONTH) <= last_date
	    AND plan_name != 'pro annual'
	)
SELECT 
	* ,
	ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY payment_date, plan_id) AS payment_order
FROM cte
WHERE amount IS NOT NULL
)
SELECT
	cur.customer_id,
	cur.plan_id,
	cur.plan_name,
	cur.payment_date,
	CASE WHEN
		pre.plan_name IN ('pro monthly','basic monthly') AND cur.plan_name = 'pro annual' THEN (cur.amount - pre.amount)
		ELSE cur.amount
	END AS amount,
	cur.payment_order
FROM info cur
LEFT JOIN 
	info pre ON cur.customer_id = pre.customer_id AND 
	cur.payment_order = pre.payment_order + 1
ORDER BY 
	customer_id, 
	payment_order, 
	plan_id
;

--D: Outside The Box Questions
DROP TABLE IF EXISTS payment;
CREATE TEMPORARY TABLE payment
WITH info AS (
WITH RECURSIVE cte AS (
	SELECT
		s.customer_id,
		s.plan_id,
		p.plan_name,
		s.start_date as payment_date,
		CASE WHEN
			LEAD(s.start_date) OVER (PARTITION BY s.customer_id ORDER BY s.start_date) IS NULL THEN (SELECT MAX(start_date) FROM subscriptions)
			ELSE LEAD(s.start_date) OVER (PARTITION BY s.customer_id ORDER BY s.start_date)
		END AS last_date,
		p.price as amount
	FROM subscriptions s
	LEFT JOIN 
		plans p ON s.plan_id = p.plan_id
	WHERE 
		p.plan_name <> 'trial'	
	UNION ALL
	SELECT 
	    customer_id,
	    plan_id,
	    plan_name,
	    DATE_ADD(payment_date, INTERVAL 1 MONTH) AS payment_date,
	    last_date,
	    amount
	FROM cte
	WHERE DATE_ADD(payment_date, INTERVAL 1 MONTH) <= last_date
	    AND plan_name != 'pro annual'
	)
SELECT 
	* ,
	ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY payment_date, plan_id) AS payment_order
FROM cte
WHERE amount IS NOT NULL
)
SELECT
	cur.customer_id,
	cur.plan_id,
	cur.plan_name,
	cur.payment_date,
	CASE WHEN
		pre.plan_name IN ('pro monthly','basic monthly') AND cur.plan_name = 'pro annual' THEN (cur.amount - pre.amount)
		ELSE cur.amount
	END AS amount,
	cur.payment_order
FROM info cur
LEFT JOIN 
	info pre ON cur.customer_id = pre.customer_id AND 
	cur.payment_order = pre.payment_order + 1
ORDER BY 
	customer_id, 
	payment_order, 
	plan_id
;
--Q1:
SELECT
	YEAR(payment_date) AS year,
	MONTH(payment_date) AS month,
	COUNT(DISTINCT customer_id) AS num_pay,
	SUM(amount) AS total_amount
FROM payment 
WHERE plan_id <> 0
GROUP BY 1,2;

-- Q2:
WITH cte AS (
SELECT
	payment_date as start_date,
	plan_id,
	customer_id
FROM payment
UNION ALL
SELECT
	start_date,
	plan_id,
	customer_id
FROM subscriptions
WHERE plan_id IN (0,4)
ORDER BY customer_id, plan_id
)
SELECT
	YEAR(start_date) AS year,
	MONTH(start_date) AS month,
	COUNT(DISTINCT CASE WHEN plan_id = 4 THEN customer_id ELSE NULL END) AS num_churn,
	COUNT(DISTINCT customer_id) AS num_total,
	COUNT(DISTINCT CASE WHEN plan_id = 4 THEN customer_id ELSE NULL END)/COUNT(DISTINCT customer_id) AS churn_pct
FROM cte
GROUP BY 1,2;

