WITH product_details AS (
SELECT  -- concat 3 table product hierachy together with inner join.
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



