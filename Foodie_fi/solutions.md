## Case study #3: Foodie-Fi App

Foodie-Fi App has a similar concept to Netflix but focuses only on cooking shows.

This case uses historical subscription data to analyse and diagnose the business' health.
The company ran a trial in 2020.

<details>
<summary><h3>Datasets</summary>	
  There are 2 tables in the schema, including `plans` and `subscriptions`.
  
  The `plans` table contains information about different subscription plans of the app (e.g. id, name and price)
  
  ![image](https://user-images.githubusercontent.com/114192113/219335827-40ccadfd-1325-4d39-b83a-c274de0c4d1f.png)

  The `subscriptions` table provides information about changing plans of each customer from Jan 2020 to Apr 2021.
  
  ![image](https://user-images.githubusercontent.com/114192113/219336957-1981f9a6-9dd9-4456-ba09-3acc38d8c48a.png)

  </details>
  
  <details>
<summary><h3>A. Customer journey</summary>	

**Question :** Write a query description about each customer’s onboarding journey.
  
```sql
USE foodie_fi;
SELECT
	s.customer_id,
	GROUP_CONCAT(p.plan_name SEPARATOR ' -> ') as journey,
	GROUP_CONCAT(s.start_date SEPARATOR ' -> ') as time_line
FROM subscriptions s
LEFT JOIN plans p
	ON s.plan_id = p.plan_id
GROUP BY s.customer_id;
 
```
  
![image](https://user-images.githubusercontent.com/114192113/219346750-a96aed29-9514-490d-a25e-0eaaa698ce5e.png)
  
 It shows the journey of each customer and also the timeline. Some customers started with a trial plan and then upgraded to a monthly and annual plan. 
 It is a 7-day trial.
  
  </details>
    
 <details>
<summary><h3>B. Data Analysis Questions </summary>	
  
 **Question 1:** How many customers has Foodie-Fi ever had?
  
  ```sql
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
  
  ```
  
  ![image](https://user-images.githubusercontent.com/114192113/219347492-73d4cc67-1734-4c20-a32c-b794634934f8.png)

  The company has 1000 customers who used the trial and made 2650 changes in the plan. 
  
 **Question 2:** What is the monthly distribution of trial plan start_date values for 
  our dataset - use the start of the month as the group by value.
  
  ``` sql
  SELECT
	MONTH(start_date) AS month,
	COUNT(DISTINCT customer_id) AS num_customer
FROM subscriptions
WHERE plan_id = 0
GROUP BY 1;
  ```
  
  ![image](https://user-images.githubusercontent.com/114192113/219349442-d05d0640-82da-4614-878f-f0420c578ccd.png)

The number of trials by month is similar, except Feb (which has only 28 days).
It would be more clear by using histogram visualisation. 
 
 **Question 3:** What plan start_date values occur after 2020 for our dataset? 
  Show the breakdown by the count of events for each plan_name
  
  ```sql
  
  SELECT
	s.plan_id,
	p.plan_name,
	COUNT(DISTINCT s.customer_id) AS event_2020,
	COUNT(DISTINCT CASE WHEN s.start_date >= '2021-01-01' THEN s.customer_id ELSE NULL END) AS event_2021
FROM subscriptions s
RIGHT JOIN 
	plans p ON s.plan_id = p.plan_id
GROUP BY 1;

  ```
 ![image](https://user-images.githubusercontent.com/114192113/219352026-fca358d6-13ed-458d-93ff-c5a748aba728.png)
 
 The trial campaign ran only in 2020. The data for 2021 has only 4 months and did not have a trial, so customers had not changed plans as much as in 2020.
 Note: the data in that part only shows how many times the plan changed, not the number of customers.
  
   **Question 4:** What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
  
  ```sql
  SELECT
	COUNT(DISTINCT customer_id) AS churn_count,
	ROUND(COUNT(DISTINCT customer_id)/(SELECT COUNT(DISTINCT customer_id) FROM subscriptions)*100,1) AS churn_pct
FROM subscriptions
WHERE plan_id = 4;

  ```
  ![image](https://user-images.githubusercontent.com/114192113/219353433-1d01ab36-c96c-4860-8138-09899a8aadc7.png)

 Among 1000 trial customers, there are 307 customers, ~ 30.7%, who have churned after 16 months.
  
   **Question 5:** How many customers have churned straight after their initial free trial - 
  what percentage is this rounded to the nearest whole number?
  
  ```sql
  WITH ranking AS (
SELECT -- order changing times by time
	plan_id,
	customer_id,
	start_date,
	ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY start_date) AS time_rank
FROM subscriptions
)
SELECT -- get the second change which is 'churn'
	COUNT(DISTINCT customer_id) AS churn_after_trial_count,
	ROUND(COUNT(DISTINCT customer_id)/(SELECT COUNT(DISTINCT customer_id) FROM subscriptions)*100,1) AS churn_after_trial_pct
FROM ranking
WHERE 
	plan_id = 4 AND 
	time_rank = 2;
  ```
 ![image](https://user-images.githubusercontent.com/114192113/219354542-c77d6f34-ce68-45c6-a157-31a7e3a339a9.png)

  Among 1000 trial customers, after a 7-day trial, only 9.2% stopped using the app. In my opinion, it was a promising number.
	
**Question 6:** What is the number and percentage of customer plans after their initial free trial?

From question 5, the answer for the question is 100% - 9.2% = 90.8%. However, it is more clear to break it down into different plans.
	
```sql
WITH ranking AS (
SELECT -- order changing times
	plan_id,
	customer_id,
	start_date,
	ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY start_date) AS time_rank
FROM subscriptions)

SELECT -- get the second change which is not 'churn'
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
```
![image](https://user-images.githubusercontent.com/114192113/221857392-21327205-7fad-45b1-bc95-7bd988a79291.png)

**Question 7:** What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?

**Question 8:** How many customers have upgraded to an annual plan in 2020?
```sql
SELECT
	p.plan_name,
	COUNT(DISTINCT s.customer_id) as num_customer
FROM subscriptions s
LEFT JOIN 
	plans p ON s.plan_id = p.plan_id
WHERE 
	p.plan_name = 'pro annual' AND
	YEAR(s.start_date) = '2020';
	
```
	
![image](https://user-images.githubusercontent.com/114192113/221858582-a08e1372-5f24-4256-9e87-37020fd526f6.png)

**Question 9:** How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
	
```sql
SELECT -- get customer using an annual plan.
	COUNT(DISTINCT s.customer_id) AS pro_annual_customer,
	ROUND(AVG(DATEDIFF(start_date,join_date))) AS avg_days_to_upgrade
FROM subscriptions s
LEFT JOIN
	(SELECT -- get the join date
		MIN(start_date) as join_date,
		customer_id
	FROM subscriptions
	GROUP BY 2) AS j 
	ON s.customer_id = j.customer_id
WHERE plan_id = 3;
```

![image](https://user-images.githubusercontent.com/114192113/221858853-5bfa6382-5bad-47d8-97a6-7ca08647f642.png)


**Question 10:** Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)

```sql
WITH cte AS (
SELECT --get customer using an annual plan.
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
SELECT -- group and count customer by time ranges
	CONCAT(bucket*30, '-', (bucket * 30 - 1)+30, ' days') as days_to_upgrade_range, 
	COUNT( DISTINCT pro_annual_customer) as num_customer
FROM  cte
GROUP BY bucket;
```
 
![image](https://user-images.githubusercontent.com/114192113/221860132-b19f4109-580b-4c2c-b2d8-bc5cbc70e0f0.png)

**Question 11:** How many customers downgraded from a pro monthly to a basic monthly plan in 2020?
	
```sql
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
```
 ![image](https://user-images.githubusercontent.com/114192113/221860599-638eef22-297c-4b39-863d-33aa9a085111.png)

</details>

 <details>
<summary><h3>C. Challenge Payment Question </summary>	

**Question:** The Foodie-Fi team wants you to create a new payments table for the year 2020 that includes amounts paid by each customer in the subscriptions table with the following requirements:

- monthly payments always occur on the same day of month as the original start_date of any monthly paid plan
	
- upgrades from basic to monthly or pro plans are reduced by the current paid amount in that month and start immediately
	
- upgrades from pro monthly to pro annual are paid at the end of the current billing period and also starts at the end of the month period
	
- once a customer churns they will no longer make payments

**Answer :**
	
Using recursive to get the last date of a plan (It could be the start day of a new plan or '2020-12-31') and add 1 month into the start date to get the payment date until the payment day > the last date (because the customer changed the plan, so no more payment date for the old plan). Moreover, adding row numbers with window functions to get payment orders.
	
![image](https://user-images.githubusercontent.com/114192113/221866371-8d14e6f1-ed39-4a78-ad83-f1d393198c22.png)

Join 2 cte: one for the current plan, and one for the previous plan to calculate the amount.
	
![image](https://user-images.githubusercontent.com/114192113/221866606-fe39c51e-1541-4833-b17d-20cd097c3001.png)
	
```sql
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
	
```				       
![image](https://user-images.githubusercontent.com/114192113/221871410-c4df3225-537a-401f-ac0a-363452f362ae.png)

</details>


				       
