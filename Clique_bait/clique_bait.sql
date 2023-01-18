-- SQL Challenge: CLIQUE BAIT STORE
-- PART 1: Create an Enterprise Relationship Diagram (ERD) for the clique_bait datasets. 

-- PART 2: Digital Analysis
-- Question 1
SELECT 
	COUNT(DISTINCT user_id) AS users
FROM users;

-- Question 2
SELECT
	COUNT(cookie_id)/COUNT(DISTINCT user_id) AS avg_cookies
FROM users;

-- Question 3
SELECT 
	MONTH(event_time) AS month,
	COUNT(DISTINCT visit_id) AS visits
FROM events
GROUP BY 1;

-- Question 4
SELECT
	*
FROM events
WHERE event_type IS NULL;

SELECT
	ei.event_name,
	COUNT(e.visit_id)AS counts
FROM events e
LEFT JOIN event_identifier ei
	ON e.event_type = ei.event_type
GROUP BY 1
ORDER BY 2 DESC;

-- Question 5:
SELECT
	ei.event_name,
	COUNT(e.visit_id) AS visits,
	COUNT(e.visit_id)/(SELECT COUNT(visit_id) FROM events) AS visit_pct
FROM events e
LEFT JOIN event_identifier ei
	ON e.event_type = ei.event_type
GROUP BY 1
ORDER BY 2 DESC;

--Question 6:

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

-- Question 7
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

-- Question 8:
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

-- Question 9:
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

-- PART 3
--Create product_sales table
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


-- Create category table 
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

--PART 3: Product Funnel Analysis
-- Question 1: 
SELECT 
	product,
	views,
	cart_adds,
	purchases
FROM product_sales
WHERE 
	views = (SELECT MAX(views) FROM product_sales);
	
SELECT 
	product,
	views,
	cart_adds,
	purchases
FROM product_sales
WHERE 
	cart_adds = (SELECT MAX(cart_adds) FROM product_sales);

SELECT 
	product,
	views,
	cart_adds,
	purchases
FROM product_sales
WHERE 
	purchases = (SELECT MAX(purchases) FROM product_sales);

--Question 2:
SELECT 
	product_id,
	product,
	abandoned,
	abandoned/cart_adds AS abandoned_pct
FROM product_sales
ORDER BY 4 DESC;

-- Question 3:
SELECT 
	product_id,
	product,
	purchases/views AS view_to_purchase_pct
FROM product_sales
ORDER BY 3 DESC;

-- Question 4&5
SELECT 
	AVG(cart_adds/views) AS view_to_add_ctr,
	AVG(purchases/cart_adds) AS add_to_purchase_ctr
FROM product_sales;

-- Part 4
-- Create campaign table
DROP TABLE IF EXISTS campaign_performance;
CREATE TABLE campaign_performance AS
WITH cart_products AS (
SELECT -- get info of products added to the cart
	e.visit_id,
	e.sequence_number,
	GROUP_CONCAT(ph.page_name SEPARATOR ', ') AS cart_products
FROM events e
LEFT JOIN page_hierarchy ph
	ON e.page_id = ph.page_id
WHERE 
	e.event_type = 2
GROUP BY 1
ORDER BY 1,2
)
SELECT -- compute metrics
	u.user_id,
	e.visit_id,
	ci.campaign_name,
	MIN(event_time) AS visit_start_time,
	SUM(CASE WHEN event_type = 1 THEN 1 ELSE 0 END) AS view_product,
	SUM(CASE WHEN event_type = 2 THEN 1 ELSE 0 END) AS add_cart,
	SUM(CASE WHEN event_type = 3 THEN 1 ELSE 0 END) AS purchases,
	SUM(CASE WHEN event_type = 4 THEN 1 ELSE 0 END) AS impressions,
	SUM(CASE WHEN event_type = 5 THEN 1 ELSE 0 END) AS clicks,
	cp.cart_products
FROM events e
LEFT JOIN users u
	ON e.cookie_id = u.cookie_id
LEFT JOIN campaign_identifier ci
	ON e.event_time BETWEEN ci.start_date AND ci.end_date
LEFT JOIN cart_products cp
	ON e.visit_id = cp.visit_id
GROUP BY 1,2;

--PART 4: Campaign Analysis
-- Question 1:
SELECT -- compute pct 
	impressions,
	user_count,
	view_count,
	addcart_count,
	purchase_count,
	product_view_avg,
	cart_add_avg,
	addcart_count/view_count AS view_to_add_cvr,
	purchase_count/addcart_count AS add_to_purchase_cvr,
	purchase_count/view_count AS conv_rate
FROM	(	
	SELECT -- compute metrics by impressions
		impressions,
		COUNT(DISTINCT user_id) AS user_count,
		COUNT(DISTINCT CASE WHEN view_product != 0 THEN visit_id ELSE NULL END) AS view_count,
		COUNT(DISTINCT CASE WHEN add_cart != 0 THEN visit_id ELSE NULL END) AS addcart_count,
		COUNT(DISTINCT CASE WHEN purchases != 0 THEN visit_id ELSE NULL END) AS purchase_count,
		AVG(view_product) AS product_view_avg,
		AVG(add_cart) AS cart_add_avg
	FROM campaign_performance 
	GROUP BY 1
	) 
	AS info;

-- Question 2:
SELECT -- compute pct 
	impressions,
	clicks,
	user_count,
	view_count,
	addcart_count,
	purchase_count,
	product_view_avg,
	cart_add_avg,
	addcart_count/view_count AS view_to_add_cvr,
	purchase_count/addcart_count AS add_to_purchase_cvr,
	purchase_count/view_count AS conv_rate
FROM	(	
	SELECT -- compute metrics by impressions and clicks
		impressions,
		clicks,
		COUNT(DISTINCT user_id) AS user_count,
		COUNT(DISTINCT CASE WHEN view_product != 0 THEN visit_id ELSE NULL END) AS view_count,
		COUNT(DISTINCT CASE WHEN add_cart != 0 THEN visit_id ELSE NULL END) AS addcart_count,
		COUNT(DISTINCT CASE WHEN purchases != 0 THEN visit_id ELSE NULL END) AS purchase_count,
		AVG(view_product) AS product_view_avg,
		AVG(add_cart) AS cart_add_avg
	FROM campaign_performance 
	GROUP BY 1,2
	) 
	AS info;

-- Question 3:
SELECT -- compute pct 
	campaign_name,
	user_count,
	view_count,
	addcart_count,
	purchase_count,
	product_view_avg,
	cart_add_avg,
	addcart_count/view_count AS view_to_add_cvr,
	purchase_count/addcart_count AS add_to_purchase_cvr,
	purchase_count/view_count AS conv_rate
FROM	(	
	SELECT -- compute metrics by campaign
		campaign_name,
		COUNT(DISTINCT user_id) AS user_count,
		COUNT(DISTINCT CASE WHEN view_product != 0 THEN visit_id ELSE NULL END) AS view_count,
		COUNT(DISTINCT CASE WHEN add_cart != 0 THEN visit_id ELSE NULL END) AS addcart_count,
		COUNT(DISTINCT CASE WHEN purchases != 0 THEN visit_id ELSE NULL END) AS purchase_count,
		AVG(view_product) AS product_view_avg,
		AVG(add_cart) AS cart_add_avg
	FROM campaign_performance 
	WHERE campaign_name IS NOT NULL
	GROUP BY 1
	) 
	AS info;
	


