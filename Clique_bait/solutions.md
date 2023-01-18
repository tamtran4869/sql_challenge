## Case study #6: Clique Bait Store

Clique Bait Store is an online seafood store.

This case is about supporting the team in analysis for creative solutions to calculate funnel fallout rates 
for the Clique Bait online store.

<details>
<summary><h3>Datasets</summary>	

There are a total of 5 tables (e.g. `users`, `events`, `event_identifier`, `campaign_identifier` and `page_hierarchy`) which relate to each other
and need to combine to extract the required data.

The `users` table contains cookie_id of users who visited the website.
  
![image](https://user-images.githubusercontent.com/114192113/213286825-bd2e7258-c3da-459a-af09-e1c2bf2efa95.png)

The `events` table is a major table recorded all actions of each visit in website.

![image](https://user-images.githubusercontent.com/114192113/213287251-444e904b-5ab0-4bdd-9579-eea5e8fc8ece.png)
  
The `events` table is a major table with all actions of each visit on the website.

![image](https://user-images.githubusercontent.com/114192113/213287814-b0c78cb8-d116-4929-9609-cab7d1e29b4b.png)

Promotion campaign information is stored in the `campaign_identifier`.

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

Since the number of cookies is discrete, this number could be explained: Each user has 3-4 cookies.

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
  
To make an overall view, the query gave the percentages of all events. 
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
 
Using 2 CTE tables with the first one to get the id and time of visits viewing checkout and then joining to events 
table to get the next events of these ids where the event is "purchase" (e.g. event_id=3) and count visits in the second CTE. 
From these tables, all required information was extracted.

The first table contains the id and start_time of viewing checkout page visits.
  
![image](https://user-images.githubusercontent.com/114192113/213291244-3d3c63a4-8ad4-467e-b1d6-70b43cad41fd.png)

The second table includes counts of viewing checkout page visits and purchase visits.
  
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

Using the same method with question 6 with 2 CTE: 1 for add-cart visits and 
then 1 for the next purchase event of these visits.

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
	
From Jan to Mar, the visits increased significantly, then there was a sudden drop in Apr. It could be explained by the promotion campaigns all ended at the end of Mar. Therefore, promotion campaigns played a considerable role in getting traffic to the website.
	
The ad impression and click indicated a very good click-through rate (CTR) which shows advertising material attracting users.
	
Generally, cart-add counts/view counts in all categories have similar rates, around 60-61%, which could indicate no serious problems in products or in the website interface, but we still need to investigate detail at the product level for sure. 
	
Shellfish was the leading category. There were 2 possible reasons: the attractive offers of Half Off - Treat Your Shellf(ish) and the demand of users. This also explained the peak in visits in Feb.

</details>

<details>
<summary><h3>Product Funnel Analysis</summary>	

**Question 1:** Using a single SQL query - create a new output table which has the following details: How many times was each product viewed?, how many times was each product added to cart?, how many times was each product added to a cart but not purchased (abandoned)? and how many times was each product purchased?
	
There are 3 steps to create the required table - `product_sales`

Step 1: Convert event_type into columns which 1/0 based on event_type; only the purchase event had a different rule. A product needs 2 conditions: add to cart, and the visit makes a purchase to consider as a sold product. Each row in the output table is one product with one event (view) or 2 events (add cart and purchase) in a specific visit.

![image](https://user-images.githubusercontent.com/114192113/213309215-69b031bc-2ead-4725-8867-4b261369259e.png)

Step 2: Combine steps and group by product and visit_id to flag funnels. As the image shows, the ccf365 viewed 4 products, only added a cart and bought 3.

![image](https://user-images.githubusercontent.com/114192113/213310109-93cd3519-9aa6-46e8-a86c-2f73c67421f3.png)

Step 3: Count visits by products

```sql
DROP TABLE IF EXISTS product_sales;
CREATE TABLE product_sales AS 
WITH funnel_flag AS (
	SELECT -- flag funnel steps of each product
		product_id,
		product,
		visit_id,
		MAX(view_product) AS view_madeit,
		MAX(add_cart) AS add_madeit,
		MAX(purchase) AS purchase_madeit
	FROM 	(
		SELECT -- convert event_type into column
			ph.product_id,
			ph.page_name AS product,
			e.visit_id,
			CASE WHEN e.event_type = 1 THEN 1 ELSE 0 END AS view_product,
			CASE WHEN e.event_type = 2 THEN 1 ELSE 0 END AS add_cart,
			CASE WHEN 
				e.event_type = 2 AND 
				e.visit_id IN (SELECT DISTINCT visit_id FROM events WHERE event_type =3)-- the subquery to get purchase visits
				THEN 1 
				ELSE 0 
				END AS purchase 
		FROM events e
		LEFT JOIN page_hierarchy ph
			ON e.page_id = ph.page_id
		WHERE ph.product_id IS NOT NULL
		) AS mark_step
	GROUP BY 1,2,3
	)
SELECT -- compute count by products
	product_id,
	product,
	COUNT(CASE WHEN view_madeit = 1 THEN visit_id ELSE NULL END) AS views,
	COUNT(CASE WHEN add_madeit = 1 THEN visit_id ELSE NULL END) AS cart_adds,
	COUNT(CASE WHEN add_madeit = 1 AND purchase_madeit = 0 THEN visit_id ELSE NULL END) AS abandoned,
	COUNT(CASE WHEN purchase_madeit = 1 THEN visit_id ELSE NULL END) AS purchases
FROM funnel_flag
GROUP BY 1
ORDER BY 1;	
```
![image](https://user-images.githubusercontent.com/114192113/213310290-89c3e2c8-ce78-476f-879e-1eb0c517c000.png)

**Question 2:** Additionally, create another table which further aggregates the data for the above points but this time for each product category instead of individual products.

From the `product_sales`, compute sum for each metrics and classify by category to get the `category_sales`.
	
```sql
DROP TABLE IF EXISTS category_sales;
CREATE TABLE category_sales AS
SELECT 
	ph.product_category,
	SUM(ps.views) AS views,
	SUM(ps.cart_adds) AS cart_adds,
	SUM(ps.purchases) AS purchases
FROM product_sales ps
LEFT JOIN page_hierarchy ph
	ON ps.product_id = ph.product_id
GROUP BY 1;
```
	
![image](https://user-images.githubusercontent.com/114192113/213311100-f8cfd18e-38f4-4b41-bb00-282da59f8d78.png)

**Question 3:** Which product had the most views, cart adds and purchases?

```sql
SELECT 
	'Most views' AS top,
	product,
	views,
	cart_adds,
	purchases
FROM product_sales
WHERE 
	views = (SELECT MAX(views) FROM product_sales)
UNION ALL	
SELECT 
	'Most cart adds' AS top,
	product,
	views,
	cart_adds,
	purchases
FROM product_sales
WHERE 
	cart_adds = (SELECT MAX(cart_adds) FROM product_sales)
UNION ALL
SELECT 
	'Most purchases' AS top,
	product,
	views,
	cart_adds,
	purchases
FROM product_sales
WHERE 
	purchases = (SELECT MAX(purchases) FROM product_sales);	
```
![image](https://user-images.githubusercontent.com/114192113/213312277-efbfcfee-640d-4a94-9b3e-f1138c4ff195.png)

**Question 4:** Which product was most likely to be abandoned?
```sql
SELECT 
	product_id,
	product,
	abandoned,
	abandoned/cart_adds AS abandoned_pct
FROM product_sales
ORDER BY 4 DESC;	
```
![image](https://user-images.githubusercontent.com/114192113/213312825-9f89cb32-97f9-4dc2-9f11-f77b75dd64ea.png)

**Question 5:** Which product had the highest view to purchase percentage?
```sql
SELECT 
	product_id,
	product,
	purchases/views AS view_to_purchase_pct
FROM product_sales
ORDER BY 3 DESC;	
```
![image](https://user-images.githubusercontent.com/114192113/213312992-af5d432c-ac3a-4390-8682-e3edc237cc70.png)

**Question 6 & 7:** What is the average conversion rate from view to cart add? and what is the average conversion rate from cart add to purchase?

```sql
SELECT 
	AVG(cart_adds/views) AS view_to_add_ctr,
	AVG(purchases/cart_adds) AS add_to_purchase_ctr
FROM product_sales;	
```
![image](https://user-images.githubusercontent.com/114192113/213313579-968bdb51-987b-4dfa-8da5-7a5e80c02500.png)

**Comments**

The conversion rates were extremely high. which may indicate good products, marketing and a good website; all lead to income rises. The percentage from viewing to purchasing most products was very good (greater than 44%).
	
However, the abandoned rates went up more than 20%, which was considered high. To have solutions, the company needs to investigate more about the reasons for drops after add-cart events. It could be the slow website speed, poor payment methods, poor shipping options, high prices or unfriendly checkout interface. We could use AB testing to test possible reasons. Moreover, remarketing (e.g. display, search or email marketing) is a suitable technique for reminding customers.
	
In most of the metrics, there was no significant difference between products, so at that moment, the product line was good and no need to make a massive change to it.

</details>
	
<details>
<summary><h3>Campaigns Analysis</summary>	
