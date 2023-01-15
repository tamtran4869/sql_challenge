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

Comment: 
Discount ammounts accounted for more than 10% of total revenue.

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

There are 25% of number of transactions spending less than or equal 375 usd per transactions, 50% spending less than or equal to 509 usd
and 75% transactions spending less than or equal 647 usd per transactions
