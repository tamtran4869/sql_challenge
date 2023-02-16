## Case study #3: Foodie-Fi App

Foodie-Fi App has similar concept with Netflix but focuses on only cooking shows.

This case is about using historical subscriptions data to analysis and dianogse the business' health.
The company ran trial in 2020.

<details>
<summary><h3>Datasets</summary>	
  There are 2 tables in the schema included `plans` and `subscriptions`.
  
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
  
  It shows a journey of each customer and also the time-line. Some customers started with trial plan then upgrade into monthly and annual plan 
  It is 7-day trial.
  
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

   The company has total 1000 customers who used trial and made 2650 changes in plan. 
  
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

  There is not much difference between number of trial by month, except Feb (has only 28 days).
  It would be more clear by using histogram visualsation. 
 
 **Question 3:** What plan start_date values occur after the year 2020 for our dataset? 
  Show the breakdown by count of events for each plan_name
  
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
 
  The trial campaign ran only in 2020. The data for 2021 has only 4 month and did not has trial, so customers had not changed plans as much as in 2020.
  Note: the data in that part shows only about plan changing times not about number of customers.
  
   **Question 4:** What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
  
  ```sql
  SELECT
	COUNT(DISTINCT customer_id) AS churn_count,
	ROUND(COUNT(DISTINCT customer_id)/(SELECT COUNT(DISTINCT customer_id) FROM subscriptions)*100,1) AS churn_pct
FROM subscriptions
WHERE plan_id = 4;

  ```
  ![image](https://user-images.githubusercontent.com/114192113/219353433-1d01ab36-c96c-4860-8138-09899a8aadc7.png)

  Among 1000 trial customers, there are 307 customers ~ 30.7% who have churned after 16 months
  
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

  Among 1000 trial customers, after 7-day trial, only 9.2% stopped using the app. In my opinion, it was a promising number.
  
  
  
