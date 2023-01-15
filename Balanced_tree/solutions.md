## Case study #7: Balanced Tree Clothing Company

Balanced Tree Clothing Company is proud to offer a range of clothing and lifestyle wear 
optimized for the modern adventurer! 

The CEO of this trendy fashion company, has asked to help the team's merchandising team analyze sales performance 
and create basic financial reports that can be shared across the company.

### Datasets

In this case study, there are a total of 4 tables in this case study (e.g. product_details, sales, product_hierarchy, product_prices)
.However, only 2 main tables: product_details and sales, were needed to solve all regular questions.

The product_details table contains all the information about the full range Balanced Clothing sells in its stores.
Each row is a product.

![image](https://user-images.githubusercontent.com/114192113/212568010-c76543a5-2506-4132-903e-eadaa0dfb22d.png)

The sales table includes all information about transactions (e.g. quantity, price, discount percentages, member status,
transac ID and transac time, product ID). Each row is a purchased product.

![image](https://user-images.githubusercontent.com/114192113/212568155-f0065c68-2c9a-4fc9-8a5b-59a60ed45a37.png)

### Tasks
Go to the database
```sql
USE balanced_tree
```
#### High Level Sales Analysis
1. What was the total quantity sold for all products?
``` sql
SELECT
	SUM(qty) AS total_quantity
FROM sales;
```
![image](https://user-images.githubusercontent.com/114192113/212568296-5a02b975-c631-43f6-9885-c9fee99c1f00.png)

2. What is the total generated revenue for all products before discounts?
``` sql
SELECT
	SUM(qty* price) AS total_rev_before_discount
FROM sales;
```   
![image](https://user-images.githubusercontent.com/114192113/212568349-c82a86f5-a4ce-4be0-a6b0-c6146a742242.png)

3. What was the total discount amount for all products?
``` sql
SELECT
	SUM(qty* price*(discount/100)) AS total_discount
FROM sales;
```   
![image](https://user-images.githubusercontent.com/114192113/212568378-367e39d5-0427-41da-afa4-bced06e6fbf8.png)

**Comment**

Discount ammounts accounted for more than 10% of total revenue. The company should be considered this percentage to make sure the expected ROI.

#### Transaction Analysis
1. How many unique transactions were there?

Since each row of the sales table is a purchased product, one transac may has more than 1 product = 1 row. Hence,
the COUNT DISTINCT was needed to get the unique transaction numbers. 
``` sql
SELECT
	COUNT(DISTINCT txn_id) AS total_unique_transac
FROM sales;
```  
![image](https://user-images.githubusercontent.com/114192113/212568544-c6339975-2265-4ec9-b3c6-80a62eeae42e.png)

2. What is the average unique products purchased in each transaction?

Using subquery to get count of unique product, then computing the average.

``` sql
SELECT 
	AVG(unique_prod) AS avg_unique_prod
FROM	(
	SELECT  -- count unique products each transac
		txn_id AS transac_id,
		COUNT(DISTINCT prod_id) AS unique_prod
	FROM sales
	GROUP BY 1
	) AS count_unique;
```  
![image](https://user-images.githubusercontent.com/114192113/212568716-f03ef96c-d68a-4555-b9ce-28ba80e93bf3.png)

3. What are the 25th, 50th and 75th percentile values for the revenue per transaction?

There is a function called PERCENTILE_CONT() which allows to compute percentile values of each series. However, mySQL 8 has not 
supported the function, so a defined function was created which based on the formular of percentile calculation: 

rank X = (p/100)* N with N is the total number of the series and p is the percentage wanted to calculate the percentile value.

The series is ordered ascending, the element Xth is the value of percentile p. The function takes a percentile parameter.

``` sql
DROP FUNCTION IF EXISTS get_percentile_rev;
DELIMITER $$
CREATE FUNCTION get_percentile_rev (percentile INT)
RETURNS FLOAT
DETERMINISTIC
BEGIN 
  DECLARE value FLOAT;
  
  WITH cte AS (
  SELECT
  	  num,
  	  rev
  FROM  (
	SELECT
		txn_id AS transac_id,
		SUM(qty* price) AS rev, -- the series
		ROW_NUMBER() OVER (ORDER BY SUM(qty* price)) AS num -- order the series
	FROM sales
	GROUP BY 1
	ORDER BY 2 ASC
	) AS sum
  HAVING num = ROUND((percentile/100)*(SELECT COUNT(DISTINCT txn_id) FROM sales)) -- the formular
  	)
  SELECT rev INTO value FROM cte;

  RETURN value;
END
$$
DELIMITER ;
```  
Call the function to get the answers.
```sql
SELECT 
	get_percentile_rev(25) AS revenue_at_percentile_25,
	get_percentile_rev(50) AS revenue_at_percentile_50,
	get_percentile_rev(75) AS revenue_at_percentile_75;
```
![image](https://user-images.githubusercontent.com/114192113/212569108-c16a2407-50f6-43e4-8f4a-84a0634fd9b7.png)

There are 25% of number of transactions spending less than or equal 375 usd per transaction, 50% spending less than or equal to 509 usd and 75% transactions spending less than or equal 647 usd per transaction.

4.What is the average discount value per transaction?
```sql
SELECT -- take the avg
	AVG(discount) AS discount_per_transac
FROM 	(
	SELECT -- compute sum discount amount each transac
		txn_id AS transac_id,
		SUM(qty*price*(discount/100)) AS discount
	FROM sales
	GROUP BY 1
	) AS sum_discount;
```
![image](https://user-images.githubusercontent.com/114192113/212569416-c127324d-059a-4c56-a7d4-046b29b5667f.png)

5. What is the percentage split of all transactions for members vs non-members?
```sql
SELECT -- compute the pct of transac
	total,
	member_transac,
	member_transac/total AS member_transac_pct,
	nonmember_transac,
	nonmember_transac/total AS nonmember_transac_pct	
FROM	(
	SELECT -- count transacs by membership status and the total
		COUNT(DISTINCT txn_id) AS total,
		COUNT(DISTINCT CASE WHEN member = 't' THEN txn_id ELSE NULL END) AS member_transac,
		COUNT(DISTINCT CASE WHEN member = 'f' THEN txn_id ELSE NULL END) AS nonmember_transac
	FROM sales
	)AS group_id;
```
![image](https://user-images.githubusercontent.com/114192113/212569755-32ac97e4-d94b-40b1-91d5-eff00bbf0c2c.png)

6. What is the average revenue for member transactions and non-member transactions?

```sql
SELECT - group by membership and take the avg
	member,
	AVG(rev) AS avg_rev
FROM	(
	SELECT -- sum the revenue
		member,
		txn_id,
		sum(qty*price) AS rev
	FROM sales
	GROUP BY txn_id
	)AS group_id
GROUP BY 1;
```
![image](https://user-images.githubusercontent.com/114192113/212569919-65150ec9-ff62-4491-9a9a-95c3bd33f271.png)

**Comments**

Each transaction has average 6 unique products which means the customers tent to buy many types of clothes in 1 purchasing. It is good to create cross-sell promotion to push low sales items with the high ones or redundant items together for boosting sales. 

Although there is not much different between member and non-member average values in one bill, the members bought more time than non-member customers (more than 60% of transactions are from members). Therefore, promotions for joining membership should be considered and advertise more.

#### Product analysis
The hierarchy of product in this analysis included 3 levels:
Category > Segment > Product

	- Category: Men and Women

	- Segment: Jacket, jeans, shirt and socks

1.What are the top 3 products by total revenue before discount?
```sql
SELECT
	pd.product_name,
	SUM(s.qty*s.price) AS rev
FROM sales s
LEFT JOIN product_details pd
	ON s.prod_id = pd.product_id
GROUP BY 1
ORDER BY 2 DESC
LIMIT 3;
```
![image](https://user-images.githubusercontent.com/114192113/212570631-c0777f8a-0b2d-410e-bc5d-7363aa01d5a1.png)

2. What is the total quantity, revenue and discount for each segment?
```sql
SELECT	
	pd.segment_name,
	SUM(s.qty) AS qty,
	SUM(s.qty*s.price) AS rev,
	SUM(s.qty*s.price*(s.discount/100)) AS discount
FROM sales s
LEFT JOIN product_details pd
	ON s.prod_id = pd.product_id
GROUP BY 1;
```
![image](https://user-images.githubusercontent.com/114192113/212570713-f6593dae-238c-4385-8724-d3abc6df0d0b.png)

3.What is the top selling product for each segment?
```sql
SELECT -- Get the top selling (qty)
	segment_name,
	product_name AS top_selling,
	MAX(qty) AS max_qty
FROM	(
	SELECT	-- get total quantity by segment and product
		pd.segment_name,
		pd.product_name,
		SUM(s.qty) AS qty
	FROM sales s
	LEFT JOIN product_details pd
		ON s.prod_id = pd.product_id
	GROUP BY 1,2
	ORDER BY 3 DESC) AS test
GROUP BY 1;
```
![image](https://user-images.githubusercontent.com/114192113/212570777-234e0cf1-79a0-4044-8afe-e1351de63071.png)

4.What is the total quantity, revenue and discount for each category?
```sql
SELECT 
	pd.category_name,
	SUM(s.qty) AS qty,
	SUM(s.qty*s.price) AS rev,
	SUM(s.qty*s.price*(s.discount/100)) AS discount
FROM sales s
LEFT JOIN product_details pd
	ON s.prod_id = pd.product_id
GROUP BY 1;
```
![image](https://user-images.githubusercontent.com/114192113/212570936-3448e1e4-c83e-49fb-a69e-0a7236761fbb.png)

5.What is the top selling product for each category?
```sql
SELECT -- Take the max qty of each category
	category_name,
	product_name AS top_selling,
	MAX(qty) AS max_qty
FROM	(
	SELECT	-- sum qty by product and category
		pd.category_name,
		pd.product_name,
		SUM(s.qty) AS qty
	FROM sales s
	LEFT JOIN product_details pd
		ON s.prod_id = pd.product_id
	GROUP BY 1,2
	ORDER BY 3 DESC) AS test
GROUP BY 1;
```
![image](https://user-images.githubusercontent.com/114192113/212570981-a77a8c69-72a2-4c3c-af18-6124137d4c9f.png)

6. What is the percentage split of revenue by product for each segment?

```sql
SELECT -- compute the percentage
	segment_name,
	product_name,
	rev/total_rev AS rev_pct
FROM	(
	SELECT  -- compute the sum of rev by segment and product with window functions
		pd.segment_name,
		pd.product_name,
		SUM(s.qty*s.price) OVER (PARTITION BY product_name)AS rev,
		SUM(s.qty*s.price) OVER (PARTITION BY segment_name) AS total_rev
	FROM sales s
	LEFT JOIN product_details pd
		ON s.prod_id = pd.product_id
	) AS sum_rev
GROUP BY 1,2
ORDER BY 1,3 DESC;	
```
![image](https://user-images.githubusercontent.com/114192113/212571060-e2af77f4-ca8a-49cc-b094-7c3b4cf9ffcf.png)

7.What is the percentage split of revenue by segment for each category?

It is the same with the question 6 instead of grouping by segments and  products, this question is for categories and segments.
```sql
SELECT -- compute the percentage
	category_name,
	segment_name,
	rev/total_rev AS rev_pct
FROM	(
	SELECT -- compute the sum of rev by category and segment with window functions
		pd.category_name,
		pd.segment_name,
		SUM(s.qty*s.price) OVER (PARTITION BY segment_name)AS rev,
		SUM(s.qty*s.price) OVER (PARTITION BY category_name) AS total_rev
	FROM sales s
	LEFT JOIN product_details pd
		ON s.prod_id = pd.product_id
	) AS sum_rev
GROUP BY 1,2
ORDER BY 1,3 DESC;	
```
![image](https://user-images.githubusercontent.com/114192113/212571262-1d79ae3f-4740-463b-800b-8a592d07c8d0.png)

8.What is the percentage split of total revenue by category?
```sql
SELECT 
	pd.category_name,
	SUM(s.qty*s.price)/(SELECT SUM(qty*price) FROM sales) AS rev_pct -- the subquery for the total revenue
FROM sales s
LEFT JOIN product_details pd
	ON s.prod_id = pd.product_id
GROUP BY 1;
```
![image](https://user-images.githubusercontent.com/114192113/212571301-48301ae4-d84f-4d54-b4b8-2446be4a56ea.png)

9.What is the total transaction “penetration” for each product? (hint: penetration = number of transactions where at least 1 quantity of a product was purchased divided by total number of transactions)

```sql
SELECT
	s.prod_id,
	pd.product_name,
	COUNT(DISTINCT s.txn_id) AS transac,
	COUNT(DISTINCT s.txn_id)/(SELECT COUNT(DISTINCT txn_id) FROM sales) AS penetration -- the subquery for the total transactions
FROM sales s
LEFT JOIN product_details pd
	ON s.prod_id = pd.product_id
GROUP BY 1
ORDER BY 4 DESC;
```
![image](https://user-images.githubusercontent.com/114192113/212571445-a2b6feb5-c0fa-4d85-8e88-8ec4e437d137.png)

10.What is the most common combination of at least 1 quantity of any 3 products in a 1 single transaction?

Using 2 CROSS JOIN to make combination of any 3 products and counting. With any 3 products, there are 6 combinations (accounting the order). The first 6 rows are for all the same 3 products with same time of combinations, so we can take any one of them.

![image](https://user-images.githubusercontent.com/114192113/212571628-a01a4605-05a0-48ae-afc6-d58267a2d212.png)

```sql
WITH cte AS (
	SELECT
		s1.prod_id AS p1,
		s2.prod_id AS p2,
		s3.prod_id AS p3,
		COUNT(DISTINCT s1.txn_id) AS time
	FROM sales s1
	CROSS JOIN sales s2 
		ON s2.txn_id = s1.txn_id
	CROSS JOIN sales s3 
		ON s3.txn_id = s1.txn_id
	GROUP BY 1,2,3
	HAVING	
		s3.prod_id <> s2.prod_id
		AND s1.prod_id <> s2.prod_id
		AND s1.prod_id <> s3.prod_id 
	ORDER BY 4 DESC
	LIMIT 10 
	)

SELECT -- get the name of the product
	pd1.product_name AS p1,
	pd2.product_name AS p2,
	pd3.product_name AS p3,
	time
FROM cte
LEFT JOIN product_details pd1
	ON cte.p1 = pd1.product_id
LEFT JOIN product_details pd2
	ON cte.p2 = pd2.product_id
LEFT JOIN product_details pd3
	ON cte.p3 = pd3.product_id;
```

![image](https://user-images.githubusercontent.com/114192113/212571688-15ec74c4-6e72-4bde-8f15-1cd26bb9fc0c.png)

**Comments**

There are many information but here are some interesting insights:

There are only 2 products in each segment accounted total from around 80% - 90% of revenues each segment.The company should get trend analysis of these products, if there would be a significant downtrend, that means a times of promoting new products. Or the company could make the product porfolio more diversity with new products that have similar design with these popular products because it is less risky for the company with various of main products.

The shirt and jeans are major segments.

Although the quantity of women category is higher than men, the revenue of woment category is lower. Hence, the average price of men items is higher than women items. The men category also accounted for 55% of revenue. It is very interesting. There are 2 new ways to increase the revenue in term of operation (not manufacturing): increase the price of women items reasonablaly (e.g. special collections, unique items) and try make more purchases on men products (e.g. combo packages, reasonable discount).

The customers usually buy men and womens items together. They might go shopping with their family. The company could run promotion for mixing men and women items, display the store with couple items and family items.

### Reporting Challenge

Write a single SQL script that combines all of the previous questions into a scheduled report that the Balanced Tree team can run at the beginning of each month to calculate the previous month’s values.

All these previous queries were rewrote in form of functions and procedures with an additional WHEN statement. Then 
one full report procedure with month parameter run all these functions and procedures to get the report monthly.

For example:

Question 1:
```sql
SELECT
	SUM(qty) AS total_quantity
FROM sales;

```
Tranfer to the function to get total quantity:
```sql
DROP FUNCTION IF EXISTS get_total_qty;
DELIMITER $$
CREATE FUNCTION get_total_qty (month INT)
RETURNS INT
DETERMINISTIC
BEGIN 
  DECLARE total INT;
  SET total = (
	  SELECT SUM(qty)
	  FROM sales
	  WHERE MONTH(start_txn_time) = month
	  );
  RETURN total;
END
$$
DELIMITER ;
```

The full SQL script is here.

The final report procedure:
```sql
DROP PROCEDURE IF EXISTS proc_report;
DELIMITER //
CREATE PROCEDURE proc_report (month INT)
BEGIN 
	SELECT  get_total_qty(month) AS total_qty; 
	SELECT	get_rev_before_discount(month) AS rev_before_discount;
	SELECT	get_total_discount(month) AS total_discount;
	SELECT	get_total_unique_transac(month);
	SELECT	get_percentile_rev(25,month) AS revenue_at_percentile_25;
	SELECT	get_percentile_rev(50,month) AS revenue_at_percentile_50;
	SELECT	get_percentile_rev(75,month) AS revenue_at_percentile_75;
	SELECT	get_avg_discount(month) AS avg_discount;
	
	CALL 	proc_transac_by_membership(month);
	CALL 	proc_rev_by_membership(month);	
	CALL 	proc_top_rev_before_discount(month,3);
	CALL	proc_segment_info(month);
	CALL	proc_segment_top_selling(month) ;
	CALL	proc_category_info(month);
	CALL	proc_category_top_selling(month);
	CALL	proc_product_pct(month);
	CALL	proc_segment_pct(month);
	CALL	proc_category_pct(month);
	CALL	proc_penetration(month) ;
	CALL	proc_top_combination(month) ;

END
//
DELIMITER ;
```





