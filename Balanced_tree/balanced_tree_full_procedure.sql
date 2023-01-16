-- SQL challenge: BALANCED TREE CLOTHING COMPANY
-- Creating functions and stored procedure for making monthly reports easier.

-- HIGH SALES LEVEL ANALYSIS
-- Question 1
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

-- Question 2
DROP FUNCTION IF EXISTS get_rev_before_discount;
DELIMITER $$
CREATE FUNCTION get_rev_before_discount (month INT)
RETURNS INT
DETERMINISTIC
BEGIN 
  DECLARE total INT;
  SET total = (
	  SELECT SUM(qty*price)
	  FROM sales
	  WHERE MONTH(start_txn_time) = month
	  );
  RETURN total;
END
$$
DELIMITER ;

--Question 3
DROP FUNCTION IF EXISTS get_total_discount;
DELIMITER $$
CREATE FUNCTION get_total_discount (month INT)
RETURNS INT
DETERMINISTIC
BEGIN 
  DECLARE total INT;
  SET total = (
	  SELECT SUM(qty*price*(discount/100))
	  FROM sales
	  WHERE MONTH(start_txn_time) = month
	  );
  RETURN total;
END
$$
DELIMITER ;


-- TRANSACTION ANALYSIS
--Question 1
DROP FUNCTION IF EXISTS get_total_unique_transac;
DELIMITER $$
CREATE FUNCTION get_total_unique_transac(month INT)
RETURNS INT
DETERMINISTIC
BEGIN 
  DECLARE total INT;
  SET total = (
	  SELECT COUNT(DISTINCT txn_id)
	  FROM sales
	  WHERE MONTH(start_txn_time) = month
	  );
  RETURN total;
END
$$
DELIMITER ;

-- Question 2:
DROP FUNCTION IF EXISTS get_avg_unique_prod;
DELIMITER $$
CREATE FUNCTION get_avg_unique_prod(month INT)
RETURNS INT
DETERMINISTIC
BEGIN 
  DECLARE total INT;
  SET total = (
	SELECT 
		AVG(unique_prod) AS avg_unique_prod
	FROM	(
		SELECT 
			txn_id AS transac_id,
			COUNT(DISTINCT prod_id) AS unique_prod
		FROM sales
		WHERE MONTH(start_txn_time) = month
		GROUP BY 1
		) AS count_unique
	  );
  RETURN total;
END
$$
DELIMITER ;


--Question 3
DROP FUNCTION IF EXISTS get_percentile_rev;
DELIMITER $$
CREATE FUNCTION get_percentile_rev (percentile INT, month INT)
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
	WHERE MONTH(start_txn_time) = month
	GROUP BY 1
	ORDER BY 2 ASC
	) AS sum
  HAVING num = ROUND((percentile/100)*(SELECT COUNT(DISTINCT txn_id) FROM sales WHERE MONTH(start_txn_time) = month))
  	)
  SELECT rev INTO value FROM cte;

  RETURN value;
END
$$
DELIMITER ;

--Question 4
DROP FUNCTION IF EXISTS get_avg_discount;
DELIMITER $$
CREATE FUNCTION get_avg_discount(month INT)
RETURNS INT
DETERMINISTIC
BEGIN 
  DECLARE total INT;
  SET total = (
	  SELECT
	AVG(discount) AS discount_per_transac
	FROM 	(
		SELECT 
			txn_id AS transac_id,
			SUM(qty*price*(discount/100)) AS discount
		FROM sales
		WHERE MONTH(start_txn_time) = month
		GROUP BY 1
	) AS sum_discount
	);
  RETURN total;
END
$$
DELIMITER ;

-- Question 5
DROP PROCEDURE IF EXISTS proc_transac_by_membership;
DELIMITER //
CREATE PROCEDURE proc_transac_by_membership(month INT)
BEGIN
	SELECT
		total,
		member_transac,
		member_transac/total AS member_transac_pct,
		nonmember_transac,
		nonmember_transac/total AS nonmember_transac_pct	
	FROM	(
		SELECT
			COUNT(DISTINCT txn_id) AS total,
			COUNT(DISTINCT CASE WHEN member = 't' THEN txn_id ELSE NULL END) AS member_transac,
			COUNT(DISTINCT CASE WHEN member = 'f' THEN txn_id ELSE NULL END) AS nonmember_transac
		FROM sales
		WHERE MONTH(start_txn_time) = month
		)AS group_id;
END
//
DELIMITER ;


-- Question 6
DROP PROCEDURE IF EXISTS proc_rev_by_membership;
DELIMITER //
CREATE PROCEDURE proc_rev_by_membership(month INT)
BEGIN
	SELECT
		member,
		AVG(rev) AS avg_rev
	FROM	(
		SELECT
			member,
			txn_id,
			sum(qty*price) AS rev
		FROM sales
		WHERE MONTH(start_txn_time) = month
		GROUP BY txn_id
		)AS group_id
	GROUP BY 1;
END
//
DELIMITER ;


-- PRODUCT ANALYSIS
-- Question 1
DROP PROCEDURE IF EXISTS proc_top_rev_before_discount;
DELIMITER //
CREATE PROCEDURE proc_top_rev_before_discount(month INT,n INT)
BEGIN
	SELECT
		pd.product_name,
		SUM(s.qty*s.price) AS rev
	FROM sales s
	LEFT JOIN product_details pd
		ON s.prod_id = pd.product_id
	WHERE MONTH(start_txn_time) = month
	GROUP BY 1
	ORDER BY 2 DESC
	LIMIT n;
END
//
DELIMITER ;

-- Question 2
DROP PROCEDURE IF EXISTS proc_segment_info;
DELIMITER //
CREATE PROCEDURE proc_segment_info(month INT)
BEGIN
	SELECT	
		pd.segment_name,
		SUM(s.qty) AS qty,
		SUM(s.qty*s.price) AS rev,
		SUM(s.qty*s.price*(s.discount/100)) AS discount
	FROM sales s
	LEFT JOIN product_details pd
		ON s.prod_id = pd.product_id
	WHERE MONTH(start_txn_time) = month
	GROUP BY 1;
END
//
DELIMITER ;

-- Question 3
DROP PROCEDURE IF EXISTS proc_segment_top_selling;
DELIMITER //
CREATE PROCEDURE proc_segment_top_selling(month INT)
BEGIN
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
		WHERE MONTH(start_txn_time) = month
		GROUP BY 1,2
		ORDER BY 3 DESC) AS test
	GROUP BY 1;
END
//
DELIMITER ;

-- Question 4
DROP PROCEDURE IF EXISTS proc_category_info;
DELIMITER //
CREATE PROCEDURE proc_category_info(month INT)
BEGIN
	SELECT 
		pd.category_name,
		SUM(s.qty) AS qty,
		SUM(s.qty*s.price) AS rev,
		SUM(s.qty*s.price*(s.discount/100)) AS discount
	FROM sales s
	LEFT JOIN product_details pd
		ON s.prod_id = pd.product_id
	WHERE MONTH(start_txn_time) = month
	GROUP BY 1;
END
//
DELIMITER ;

-- Question 5
DROP PROCEDURE IF EXISTS proc_category_top_selling;
DELIMITER //
CREATE PROCEDURE proc_category_top_selling(month INT)
BEGIN
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
		WHERE MONTH(start_txn_time) = month
		GROUP BY 1,2
		ORDER BY 3 DESC) AS test
	GROUP BY 1;
END
//
DELIMITER ;

-- Question 6
DROP PROCEDURE IF EXISTS proc_product_pct;
DELIMITER //
CREATE PROCEDURE proc_product_pct(month INT)
BEGIN
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
		WHERE MONTH(start_txn_time) = month
		) AS sum_rev
	GROUP BY 1,2
	ORDER BY 1,3 DESC;
END
//
DELIMITER ;

-- Question 7
DROP PROCEDURE IF EXISTS proc_segment_pct;
DELIMITER //
CREATE PROCEDURE proc_segment_pct(month INT)
BEGIN
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
		WHERE MONTH(start_txn_time) = month
		) AS sum_rev
	GROUP BY 1,2
	ORDER BY 1,3 DESC;
END
//
DELIMITER ;

-- Question 8
DROP PROCEDURE IF EXISTS proc_category_pct;
DELIMITER //
CREATE PROCEDURE proc_category_pct(month INT)
BEGIN
	SELECT 
		pd.category_name,
		SUM(s.qty*s.price)/(SELECT SUM(qty*price) FROM sales WHERE MONTH(start_txn_time) = month) AS rev_pct
	FROM sales s
	LEFT JOIN product_details pd
		ON s.prod_id = pd.product_id
	WHERE MONTH(start_txn_time) = month
	GROUP BY 1;
END
//
DELIMITER ;

-- Question 9
DROP PROCEDURE IF EXISTS proc_penetration;
DELIMITER //
CREATE PROCEDURE proc_penetration(month INT)
BEGIN
	SELECT
		s.prod_id,
		pd.product_name,
		COUNT(DISTINCT s.txn_id) AS transac,
		COUNT(DISTINCT s.txn_id)/(SELECT COUNT(DISTINCT txn_id) FROM sales WHERE MONTH(start_txn_time) = month) AS penetration
	FROM sales s
	LEFT JOIN product_details pd
		ON s.prod_id = pd.product_id
	WHERE MONTH(start_txn_time) = month
	GROUP BY 1
	ORDER BY 4 DESC;
END
//
DELIMITER ;

-- Question 10
DROP PROCEDURE IF EXISTS proc_top_combination;
DELIMITER //
CREATE PROCEDURE proc_top_combination(month INT)
BEGIN
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
		WHERE 
			MONTH(s1.start_txn_time) = month AND
			MONTH(s2.start_txn_time) = month AND
			MONTH(s3.start_txn_time) = month 
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
END
//
DELIMITER ;

-- FINAL FULL PROCEDURE
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
