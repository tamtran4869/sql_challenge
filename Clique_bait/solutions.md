## Case study #6: Clique Bait Store

Clique Bait Store is online seafood store.

This case is about supporting to the team in analysis for creative solutions to calculate funnel fallout rates 
for the Clique Bait online store.

<details>
<summary><h3>Datasets</summary>	

There are a total of 5 tables (e.g. `users`, `events`, `event_identifier`, `campaign_identifier` and `page_hierarchy`) which relate to each other
and need to combine for extracting required data.

The `users` table contains cookie_id of users who visited the website.
  
![image](https://user-images.githubusercontent.com/114192113/213286825-bd2e7258-c3da-459a-af09-e1c2bf2efa95.png)

The `events` table is a major table recorded all actions of each visit in website.

![image](https://user-images.githubusercontent.com/114192113/213287251-444e904b-5ab0-4bdd-9579-eea5e8fc8ece.png)
  
Event types are in the `event_identifier` table.

![image](https://user-images.githubusercontent.com/114192113/213287814-b0c78cb8-d116-4929-9609-cab7d1e29b4b.png)

Promotion campaigns information are stored in the `campaign_identifier`.

![image](https://user-images.githubusercontent.com/114192113/213288121-7d200fef-fcf2-459d-a33c-4a8b24f19c8c.png)

The `page_hierarchy` shows information of pages on the website.

![image](https://user-images.githubusercontent.com/114192113/213288533-bf888f7c-7595-4efb-91e8-f7a24ce705bb.png)

All datasets are on the website of the challenge: <a href="https://8weeksqlchallenge.com/case-study-6/"> case #6 datasets.</a>
  
</details>

<details>
<summary><h3>Digital Analysis</summary>	
  
Go to the database
```sql 
USE clique_bait;
```
 
**Question 1:** How many users are there?
  
 ```sql
SELECT 
	COUNT(DISTINCT user_id) AS users
FROM users;
```
![image](https://user-images.githubusercontent.com/114192113/213289209-05817eed-ca94-4206-836b-e5bfa28f0c4d.png)

**Question 2:** How many cookies does each user have on average?

```sql
SELECT
	COUNT(cookie_id)/COUNT(DISTINCT user_id) AS avg_cookies
FROM users;  
```
![image](https://user-images.githubusercontent.com/114192113/213289531-d266f12d-3038-450e-b3d1-471b4f654daf.png)

Since the number of cookies is discrete then this number could be explained: Each user has 3-4 cookies.

**Question 3:** What is the unique number of visits by all users per month?
  
```sql
SELECT 
	MONTH(event_time) AS month,
	COUNT(DISTINCT visit_id) AS visits
FROM events
GROUP BY 1;
```
![image](https://user-images.githubusercontent.com/114192113/213289780-d395f6ed-bbd7-49e2-8e31-7b53bdc723ca.png)

**Question 4:** What is the number of events for each event type?
```sql
SELECT
	ei.event_name,
	COUNT(e.visit_id)AS counts
FROM events e
LEFT JOIN event_identifier ei
	ON e.event_type = ei.event_type
GROUP BY 1
ORDER BY 2 DESC;  
```  
![image](https://user-images.githubusercontent.com/114192113/213290045-db8520c5-2ec1-4bd1-a2f2-4ce4060d2c7c.png)

**Question 5:** What is the percentage of visits which have a purchase event?
  
To make an overall view, the query gave the percentages of all event. 
The purchase event accounted for 5.43% of total visits.
```sql
SELECT
	ei.event_name,
	COUNT(e.visit_id) AS visits,
	COUNT(e.visit_id)/(SELECT COUNT(visit_id) FROM events) AS visit_pct
FROM events e
LEFT JOIN event_identifier ei
	ON e.event_type = ei.event_type
GROUP BY 1
ORDER BY 2 DESC;  
```
![image](https://user-images.githubusercontent.com/114192113/213290297-a321ec69-4b63-421a-9748-f17a4005f3c4.png)
  
**Question 6:** What is the percentage of visits which view the checkout page but do not have a purchase event?
 
Using 2 CTE tables with the first one to get id and time of visits viewing checkout and then joining to events 
table to get next events of these id where the event is purchase (e.g. event_id=3) and count visits in the second CTE. 
From these table, all required information was extracted.

The first table contains id and start_time of viewing checkout page visits
  
![image](https://user-images.githubusercontent.com/114192113/213291244-3d3c63a4-8ad4-467e-b1d6-70b43cad41fd.png)

The second tables includes counts of viewing checkout page visit and purchase visit.
  
![image](https://user-images.githubusercontent.com/114192113/213292190-c38873c7-f4bd-489c-b06b-b6f1b2a100dd.png)

Final step is to compute the percentages.
 
```sql
WITH view_checkout_id AS (
	SELECT -- get viewing checkout visits
		visit_id,
		event_time AS view_checkout_time
	FROM events e
	LEFT JOIN page_hierarchy ph
		ON e.page_id = ph.page_id
	WHERE 
		ph.page_name = 'Checkout'
	),
	
purchase_visits AS (
	SELECT -- get purchase visits from viewing checkout visit
		(SELECT COUNT(visit_id) FROM view_checkout_id) AS checkout_visits,
		COUNT(e.visit_id) AS purchase_visits
	FROM events e
	RIGHT JOIN view_checkout_id vci
		ON e.visit_id = vci.visit_id
		AND e.event_time > vci.view_checkout_time
	WHERE 
		e.event_type = 3
	)
	
SELECT
	checkout_visits,
	purchase_visits,
	purchase_visits/checkout_visits AS purchase_pct,
	checkout_visits-purchase_visits AS nonpurchase_visits,
	1-purchase_visits/checkout_visits AS nonpurchase_pct
FROM purchase_visits;
```  
![image](https://user-images.githubusercontent.com/114192113/213292671-1fb66ca9-64cc-4186-8963-dc00a97a11b4.png)

**Question 7:** What are the top 3 pages by number of views?
  
```sql
SELECT
	ph.page_name,
	COUNT(e.visit_id) AS views
FROM events e
LEFT JOIN page_hierarchy ph
	ON e.page_id = ph.page_id
WHERE 
	e.event_type = 1
GROUP BY 1
ORDER BY 2 DESC
LIMIT 3;
```
![image](https://user-images.githubusercontent.com/114192113/213292913-c8d82ccf-9037-48b3-a2fd-fab1989373d5.png)
  
**Question 8:** What is the number of views and cart adds for each product category?
```sql
SELECT
	ph.product_category,
	COUNT(CASE WHEN e.event_type = 1 THEN e.visit_id ELSE NULL END) AS views,
	COUNT(CASE WHEN e.event_type = 2 THEN e.visit_id ELSE NULL END) AS cart_adds
FROM events e
LEFT JOIN page_hierarchy ph
	ON e.page_id = ph.page_id
WHERE 
	ph.product_category IS NOT NULL
GROUP BY 1;  
```
![image](https://user-images.githubusercontent.com/114192113/213293967-e39e842b-57f2-4c56-a76c-72061c9e0812.png)

**Question 9:**  What are the top 3 products by purchases?

Using the same method with question 6 with 2 CTE: 1 for add cart visits and 
then 1 for next purchase event of these visits.

```sql
WITH cart_add_id AS (
	SELECT -- get cart adding visits
		ph.page_name AS product,
		e.visit_id,
		e.event_time AS add_cart_time
	FROM events e
	LEFT JOIN page_hierarchy ph
		ON e.page_id = ph.page_id
	WHERE e.event_type = 2
	),

purchase_visits AS (
	SELECT -- get purchase visits from add product to cart visit
		cai.product,
		COUNT(e.visit_id) AS purchase_visits
	FROM events e
	RIGHT JOIN cart_add_id cai
		ON e.visit_id = cai.visit_id
		AND e.event_time > cai.add_cart_time
	WHERE 
		e.event_type = 3
	GROUP BY 1
	)
SELECT *
FROM purchase_visits
ORDER BY 2 DESC
LIMIT 3;
```
![image](https://user-images.githubusercontent.com/114192113/213300423-bedfa630-6688-4939-a913-e7fa93d2a7cb.png)

**Comments** 
	
From Jan to Mar, the visits increased significantly, then there was a sudden drop in Apr. It could be explained by the promotion campaigns all were ended at the end of Mar. Therefore, promotion campaigns played a huge role in getting traffic to the website.
	
The ad impression and ad click indicated a very good ctr which shows advertising material attracting users.
	
Generally, cart-add counts/view counts in all category have similar rate around from 60-61% which could indicate no serious problems in products or in website interface but we still need investigate detail in product level for sure. 
	
Shellfish was the leading category. There were 2 possible reasons that the attractive offers of Half Off - Treat Your Shellf(ish) and the demand of users. This also explained the peak in visits in Feb.

</details>
