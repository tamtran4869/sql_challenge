## Case study #7: Balanced Tree Clothing Company

Balanced Tree Clothing Company is proud to offer a range of clothing and lifestyle wear 
optimized for the modern adventurer! 

The CEO of this trendy fashion company has asked to help the team's merchandising team analyze sales performance 
and create basic financial reports that can be shared across the company.

<details>
<summary><h3>Datasets</summary>	

There are a total of 4 tables, in this case study (e.g. `product_details`, `sales`, `product_hierarchy`, `product_prices`)
.However, only two main tables: `product_details` and `sales`, were needed to solve all common questions.

The `product_details` table contains all the information about the full range Balanced Clothing sells in its stores.
Each row is a product.

![image](https://user-images.githubusercontent.com/114192113/212568010-c76543a5-2506-4132-903e-eadaa0dfb22d.png)

The `sales` table includes all information about transactions (e.g. quantity, price, discount percentages, member status,
transaction ID and transaction time, and product ID). Each row is a purchased product.

![image](https://user-images.githubusercontent.com/114192113/212568155-f0065c68-2c9a-4fc9-8a5b-59a60ed45a37.png)

All datasets are on the website of the challenge: <a href="https://8weeksqlchallenge.com/case-study-7/"> case #7 datasets.</a>

</details>
	
<details>
<summary><h3>Analytical Tasks</summary>	
	
Go to the database
```sql
USE balanced_tree
```
There are 3 type of analysis in this case:
	
<details>
<summary>High Level Sales Analysis</summary>	

**Question 1:** What was the total quantity sold for all products?
``` sql
SELECT
	SUM(qty) AS total_quantity
FROM sales;
```
![image](https://user-images.githubusercontent.com/114192113/212568296-5a02b975-c631-43f6-9885-c9fee99c1f00.png)

**Question 2:** What is the total generated revenue for all products before discounts?
``` sql
SELECT
	SUM(qty* price) AS total_rev_before_discount
FROM sales;
```   
![image](https://user-images.githubusercontent.com/114192113/212568349-c82a86f5-a4ce-4be0-a6b0-c6146a742242.png)

**Question 3:** What was the total discount amount for all products?
``` sql
SELECT
	SUM(qty* price*(discount/100)) AS total_discount
FROM sales;
```   
![image](https://user-images.githubusercontent.com/114192113/212568378-367e39d5-0427-41da-afa4-bced06e6fbf8.png)

**Comment**

Discount amounts accounted for more than 10% of total revenue. The company should be considered this percentage to make sure the expected ROI.
	
</details>
	
<details>
<summary>Transaction Analysis</summary>

**Question 1:** How many unique transactions were there?

Since each row of the sales table is a purchased product, one transaction may have more than 1 product = 1 row. Hence,
the `COUNT DISTINCT` was needed to get the unique transaction numbers.
``` sql
SELECT
	COUNT(DISTINCT txn_id) AS total_unique_transac
FROM sales;
```  
![image](https://user-images.githubusercontent.com/114192113/212568544-c6339975-2265-4ec9-b3c6-80a62eeae42e.png)

**Question 2:** What is the average unique products purchased in each transaction?

Using the subquery to get the count of unique products, then computing the average.

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

**Question 3:** What are the 25th, 50th and 75th percentile values for the revenue per transaction?

There is a function called `PERCENTILE_CONT()` which allows the computation of percentile values of each series. However, MySQL 8 has not 
supported the function, so a defined function was created based on the formula of percentile calculation: 

`Rank X = (p/100)* N` with N as the total number of the series and p as the percentage wanted to calculate the percentile value.

The series is ordered ascending, and the element Xth is the value of percentile p. The function takes a percentile parameter.

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

There, 25% of the transactions spent less than or equal to 375 USD per transaction, 50% spent less than or equal to 509 USD and 75% of transactions spent less than or equal to 647 USD per transaction.

**Question 4:** What is the average discount value per transaction?
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

**Question 5:** What is the percentage split of all transactions for members vs non-members?
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

**Question 6:** What is the average revenue for member transactions and non-member transactions?

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

Each transaction has average 6 unique products, which means the customer tent to buy many types of clothes in 1 purchase. It is good to create cross-sell promotions to push low-sales items with high ones, redundant items, or out-of-style items to boost sales. 

Although it is not much difference between member and non-member average values in one bill, the members bought more times than non-member customers (more than 60% of transactions are from members). Therefore, promotions for joining membership should be considered and advertised more.

</details>	
	
<details>
<summary> Product Analysis</summary>
	
The hierarchy of product in this analysis included 3 levels:
Category > Segment > Product

	Category: Men and Women

	Segment: Jacket, jeans, shirt and socks

**Question 1:** What are the top 3 products by total revenue before discount?
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

**Question 2:** What is the total quantity, revenue and discount for each segment?
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

**Question 3:** What is the top selling product for each segment?
```sql
SELECT -- get the top selling (qty)
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

**Question 4:** What is the total quantity, revenue and discount for each category?
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

**Question 5:** What is the top selling product for each category?
```sql
SELECT -- take the max qty of each category
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

**Question 6:** What is the percentage split of revenue by product for each segment?

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

**Question 7:** What is the percentage split of revenue by segment for each category?

It is the same with question 6; instead of grouping by segments and products, this question is for categories and segments.
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

**Question 8:** What is the percentage split of total revenue by category?
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

**Question 9:** What is the total transaction “penetration” for each product? (hint: penetration = number of transactions where at least 1 quantity of a product was purchased divided by total number of transactions)

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

**Question 10:** What is the most common combination of at least 1 quantity of any 3 products in a 1 single transaction?

Using 2 `CROSS JOIN` to make all combinations of any 3 products and counting. With any 3 products, there are 6 combinations (accounting for the ordering). The first 6 rows are for all the same 3 products with the same time of combinations so that we can take any one of them.

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

There is much information, but here are some interesting insights:

There are only 2 products in each segment, accounting for around 80% - 90% of revenues.  Since it is less risky to the company with various primary products,  the company could diversify its product portfolio with new products with similar designs to these popular products. Besides, the company should get a trend analysis of major products; if there is a significant downtrend, that means a time to promote new products.

Shirts and jeans are significant segments.

Although the quantity of women category is higher than men, the revenue of the women category is lower. Hence, the average price of men's items is higher than women's items. The men's category also accounted for 55% of revenue. It is very interesting. There are 2 new ways to increase the revenue in terms of operation (not manufacturing): increase the price of women's items reasonably (e.g. special collections, unique items) and try to make more purchases of men's products (e.g. combo packages, reasonable discount).

The customers usually buy men's and women's items together. They might go shopping with their family. The company could run promotions for mixing men's and women's items and display the store with couple and family items.
	
</details>
	
</details>
	
<details>
<summary><h3>Reporting Challenge</summary>	

Write a single SQL script that combines all of the previous questions into a scheduled report that the Balanced Tree team can run at the beginning of each month to calculate the previous month’s values.

All these previous queries were rewritten in form of functions and procedures with an additional WHEN statement. Then one full report procedure with a month parameter runs all these functions and procedures to get the report monthly.

For example:

Question 1:
```sql
SELECT
	SUM(qty) AS total_quantity
FROM sales;

```
Transfer to the function to get the total quantity:
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

The full SQL script is <a href="https://github.com/tamtran4869/sql_challenge/blob/main/Balanced_tree/balanced_tree_full_procedure.sql"> here.</a>

The final report procedure:
```sql
DROP PROCEDURE IF EXISTS proc_report;
DELIMITER //
CREATE PROCEDURE proc_report (month INT)
BEGIN 
	SELECT  get_total_qty(month) AS total_qty; 
	SELECT	get_rev_before_discount(month) AS rev_before_discount;
	SELECT	get_total_discount(month) AS total_discount;
	SELECT	get_total_unique_transac(month) AS total_unique_transac;
	SELECT	get_avg_unique_prod(month) AS avg_unique_product;
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
</details>
	
<details>
<summary><h3>Bonus Challenge</summary>	
	
Use a single SQL query to transform the `product_hierarchy` and `product_prices` datasets to the `product_details` table.

The `product_hierarchy` table:
	
![image](https://user-images.githubusercontent.com/114192113/213023011-2d1a5478-677d-4e0b-b83f-455c58102e9d.png)

The `product_price` table:
	
![image](https://user-images.githubusercontent.com/114192113/213023117-c8a4a8fd-7e3b-4f3d-a2bb-01b687ccffb6.png)

By joining 3 `product_hierarchy` tables together to make each become 1 level (e.g. category, segment or style) and 
then using the final table joined to `product_prices` on style_id, the SQL query below transformed 2 above tables into the `product_details` table.
	
```sql
WITH product_details AS (
SELECT  -- join 3 table product hierachy together with inner join.
	CONCAT(ph3.level_text," ",ph2.level_text," ",ph1.level_text) AS product_name,
	ph1.id AS category_id,
	ph2.id AS segment_id,
	ph3.id AS style_id,
	ph1.level_text AS category_name,
	ph2.level_text AS segment_name,
	ph3.level_text AS style_name
FROM product_hierarchy ph1
INNER JOIN product_hierarchy ph2
	ON ph1.id = ph2.parent_id
INNER JOIN product_hierarchy ph3
	ON ph2.id = ph3.parent_id
)

SELECT -- join to get product_id and price
	pp.product_id,
	pp.price,
	pd.product_name,
	pd.category_id,
	pd.segment_id,
	pd.style_id,
	pd.category_name,
	pd.segment_name,
	pd.style_name
FROM product_details pd
LEFT JOIN product_prices pp
	ON pd.style_id = pp.id;	
```
	
![image](https://user-images.githubusercontent.com/114192113/213024108-8c4ec851-00d4-4f82-818c-a7fd6e8c9dae.png)

</details>



