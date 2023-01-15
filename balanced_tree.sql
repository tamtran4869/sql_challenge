-- SQL Challenge: BALANCED TREE CLOTHING COMPANY

-- Part1: High Level Sales Analysis
-- Question 1
SELECT
	SUM(qty) AS total_quantity
FROM sales;

-- Question 2
SELECT
	SUM(qty* price) AS total_rev_before_discount
FROM sales;

-- Question 3
SELECT
	SUM(qty* price*(discount/100)) AS total_discount
FROM sales;



-- Part 2: Transaction Analysis
-- Question 1
SELECT
	COUNT(DISTINCT txn_id) AS total_unique_transac
FROM sales;

-- Question 2

SELECT 
	AVG(unique_prod) AS avg_unique_prod
FROM	(
	SELECT 
		txn_id AS transac_id,
		COUNT(DISTINCT prod_id) AS unique_prod
	FROM sales
	GROUP BY 1
	) AS count_unique;

-- Question 3

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
		SUM(qty* price) AS rev,
		ROW_NUMBER() OVER (ORDER BY SUM(qty* price)) AS num
	FROM sales
	GROUP BY 1
	ORDER BY 2 ASC
	) AS sum
  HAVING num = ROUND((percentile/100)*(SELECT COUNT(DISTINCT txn_id) FROM sales))
  	)
  SELECT rev INTO value FROM cte;

  RETURN value;
END
$$
DELIMITER ;

SELECT 
	get_percentile_rev(25) AS revenue_at_percentile_25,
	get_percentile_rev(50) AS revenue_at_percentile_50,
	get_percentile_rev(75) AS revenue_at_percentile_75;

-- Question 4

SELECT
	AVG(discount) AS discount_per_transac
FROM 	(
	SELECT 
		txn_id AS transac_id,
		SUM(qty*price*(discount/100)) AS discount
	FROM sales
	GROUP BY 1
	) AS sum_discount;

-- Question 5:
SELECT
	member,
	AVG(rev) AS avg_rev
FROM	(
	SELECT
		member,
		txn_id,
		sum(qty*price) AS rev
	FROM sales
	GROUP BY txn_id
	)AS group_id
GROUP BY 1;


--Part3: Product Analysis
-- Question 1:
SELECT
	pd.product_name,
	SUM(s.qty*s.price) AS rev
FROM sales s
LEFT JOIN product_details pd
	ON s.prod_id = pd.product_id
GROUP BY 1
ORDER BY 2 DESC
LIMIT 3;

-- Question 2:
SELECT	
	pd.segment_name,
	SUM(s.qty) AS qty,
	SUM(s.qty*s.price) AS rev,
	SUM(s.qty*s.price*(s.discount/100)) AS discount
FROM sales s
LEFT JOIN product_details pd
	ON s.prod_id = pd.product_id
GROUP BY 1;

-- Question 3:
SELECT 
	segment_name,
	product_name AS top_selling,
	MAX(qty) AS max_qty
FROM	(
	SELECT	
		pd.segment_name,
		pd.product_name,
		SUM(s.qty) AS qty
	FROM sales s
	LEFT JOIN product_details pd
		ON s.prod_id = pd.product_id
	GROUP BY 1,2
	ORDER BY 3 DESC) AS test
GROUP BY 1;

--Question 4:
SELECT 
	pd.category_name,
	SUM(s.qty) AS qty,
	SUM(s.qty*s.price) AS rev,
	SUM(s.qty*s.price*(s.discount/100)) AS discount
FROM sales s
LEFT JOIN product_details pd
	ON s.prod_id = pd.product_id
GROUP BY 1;

-- Question 5:
SELECT 
	category_name,
	product_name AS top_selling,
	MAX(qty) AS max_qty
FROM	(
	SELECT	
		pd.category_name,
		pd.product_name,
		SUM(s.qty) AS qty
	FROM sales s
	LEFT JOIN product_details pd
		ON s.prod_id = pd.product_id
	GROUP BY 1,2
	ORDER BY 3 DESC) AS test
GROUP BY 1;

-- Question 6:
SELECT
	segment_name,
	product_name,
	rev/total_rev AS rev_pct
FROM	(
	SELECT 
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

-- Question 7:
SELECT
	category_name,
	segment_name,
	rev/total_rev AS rev_pct
FROM	(
	SELECT 
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

-- Question 8:
SELECT 
	pd.category_name,
	SUM(s.qty*s.price)/(SELECT SUM(qty*price) FROM sales) AS rev_pct
FROM sales s
LEFT JOIN product_details pd
	ON s.prod_id = pd.product_id
GROUP BY 1;

-- Question 9
SELECT
	s.prod_id,
	pd.product_name,
	COUNT(DISTINCT s.txn_id) AS transac,
	COUNT(DISTINCT s.txn_id)/(SELECT COUNT(DISTINCT txn_id) FROM sales) AS penetration
FROM sales s
LEFT JOIN product_details pd
	ON s.prod_id = pd.product_id
GROUP BY 1
ORDER BY 4 DESC;

--Question 10

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
	LIMIT 1
	)

SELECT
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
	




		
		











