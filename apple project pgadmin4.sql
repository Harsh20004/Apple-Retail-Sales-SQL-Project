-- Apple Sales Project - 1M rows sales datasets

select * from category;
select * from products;
select * from sales;
select * from stores;
select * from warranty;

-- Improving Query Performance

-- 1) Index

-- Execution time - 328.863ms
-- Planning Time - 0.101ms

-- Execution time after indexing - 5.377ms

explain analyze
select * from sales
where product_id = 'P-44'

Create index sales_product_id on sales(product_id)

-- 2) Index

-- Execution Time = 152.382ms
-- Planning Time - 0.093ms

-- Execution time after indexing - 1.301ms
explain analyze
select * from sales
where store_id = 'ST-31'

Create index sales_store_id on sales(store_id)

--3) Index

Create index sales_sale_date on sales(sale_date)

-- Business Problems
-- Medium Problems

-- 1. Find the number of stores in each country.

select 
	country,count(store_id) as total_Stores
from stores
group by country
order by count(*) desc

-- Q.2 Calculate the total number of units sold by each store

select
	sales.store_id,stores.store_name,sum(sales.quantity)
FROM sales 
join stores
on stores.store_id = sales.store_id
group by sales.store_id, stores.store_name
order by sum(sales.quantity) desc

-- Q.3 Identify how many sales occurred in December 2023.

SELECT 
	COUNT(sale_id) as total_sale 
FROM sales
WHERE TO_CHAR(sale_date, 'MM-YYYY') = '12-2023'

-- Q.4 Determine how many stores have never had a warranty claim filed.

SELECT COUNT(*) FROM stores
WHERE store_id NOT IN (
						SELECT 
							DISTINCT store_id
						FROM sales 
						RIGHT JOIN warranty 
						ON sales.sale_id = warranty.sale_id
						);

-- Q.5 Calculate the percentage of warranty claims marked as "Warranty Void".

SELECT 
	ROUND
		(COUNT(claim_id)/
						(SELECT COUNT(*) FROM warranty)::numeric 
		* 100, 
	2)as warranty_void_percentage
FROM warranty
WHERE repair_status = 'Warranty Void'

-- Q.6 Identify which store had the highest total units sold in the last year.
SELECT 
	s.store_id,
	st.store_name,
	SUM(s.quantity)
FROM sales as s
JOIN stores as st
ON s.store_id = st.store_id
WHERE sale_date >= (CURRENT_DATE - INTERVAL '1 year')
GROUP BY s.store_id, st.store_name
ORDER BY SUM(s.quantity) DESC
LIMIT 1

-- Q.7 Count the number of unique products sold in the last year.

SELECT 
	COUNT(DISTINCT product_id)
FROM sales
WHERE sale_date >= (CURRENT_DATE - INTERVAL '1 year')

-- Q.8 Find the average price of products in each category.

select 
	p.category_id,c.category_name,avg(p.price) as avg_price
from products as p
join category as c
on c.category_id=p.category_id
group by p.category_id,c.category_name
order by avg(price) desc

-- Q.9 How many warranty claims were filed in 2020?

SELECT 
	COUNT(*) as warranty_claim
FROM warranty
WHERE EXTRACT(YEAR FROM claim_date) = 2020

-- Q.10 For each store, identify the best-selling day based on highest quantity sold.

SELECT  * 
FROM
(
	SELECT 
		store_id,
		TO_CHAR(sale_date, 'Day') as day_name,
		SUM(quantity) as total_unit_sold,
		RANK() OVER(PARTITION BY store_id ORDER BY SUM(quantity) DESC) as rank
	FROM sales
	GROUP BY 1, 2
) as t1
WHERE rank = 1

-- Hard Problems

-- Q.11 Identify the least selling product in each country for each year based on total units sold.

WITH product_rank AS (
    select 
        st.country,
        EXTRACT(YEAR from s.sale_date) AS year,
        p.product_name,
        SUM(s.quantity) AS total_qty_sold,
        RANK() OVER (
            PARTITION BY st.country, EXTRACT(YEAR FROM s.sale_date)
            order by sum(s.quantity) ASC
        ) AS rank
    FROM 
        sales AS s
    JOIN 
        stores AS st ON s.store_id = st.store_id
    JOIN 
        products AS p ON s.product_id = p.product_id
    GROUP BY 
        st.country, EXTRACT(YEAR FROM s.sale_date), p.product_name
)
SELECT 
    country,
    year,
    product_name,
    total_qty_sold
from 
    product_rank
where 
    rank = 1;

-- Q.12 Calculate how many warranty claims were filed within 180 days of a product sale.

select 
		COUNT(*)
from warranty as w
left JOIN
sales as s
on w.sale_id = s.sale_id
where w.claim_date - sale_date <= 180

--Q.13  Determine how many warranty claims were filed for products launched in the last two years.

SELECT 
	p.product_name,
	COUNT(w.claim_id) as no_of_claim
FROM warranty as w
JOIN
sales as s 
ON s.sale_id = w.sale_id
JOIN products as p
ON p.product_id = s.product_id
WHERE p.launch_date >= CURRENT_DATE - INTERVAL '2 years'
GROUP BY p.product_name

-- Q.14 List the months in the last three years where sales exceeded 5,000 units in the USA.

select 
	  TO_CHAR(sale_date, 'MM-YYYY') as month,
	  sum(quantity) as total_units_sold	  
from sales as s
left join
stores as st
on 
s.store_id=st.store_id
where st.country = 'USA'
	and s.sale_date >= CURRENT_DATE - INTERVAL '3 year'
group by TO_CHAR(sale_date, 'MM-YYYY')
having sum(quantity)>5000

-- Q.15 Identify the product category with the most warranty claims filed in the last two years.

SELECT 
		c.category_name,
		count(w.claim_date) as Total_Claims
FROM warranty as w
JOIN
sales as s
on w.sale_id = s.sale_id
JOIN
products as p
on p.product_id = s.product_id
JOIN 
category as c
on c.category_id = p.category_id
WHERE w.claim_date >= CURRENT_DATE - INTERVAL '2 year'
GROUP BY c.category_name
ORDER BY 2 desc


-- Complex Problems

-- Q.16 Determine the percentage chance of receiving warranty claims after each purchase for each country!

SELECT 
	Country,
	total_unit_sold,
	total_claim,
	ROUND(COALESCE(total_claim::numeric/total_unit_sold::numeric * 100, 0),3)
	as risk
FROM
(SELECT 
	st.country,
	SUM(s.quantity) as total_unit_sold,
	COUNT(w.claim_id) as total_claim
FROM sales as s
JOIN stores as st
ON s.store_id = st.store_id
LEFT JOIN 
warranty as w
ON w.sale_id = s.sale_id
GROUP BY 1) t1
where COALESCE(total_claim::numeric/total_unit_sold::numeric * 100, 0)>0
ORDER BY 4 DESC

-- Q.17 Analyze the year-by-year growth ratio for each store.

WITH yearly_sales 
as
(
	select 
			s.store_id,
			st.store_name,
			EXTRACT (year from sale_date) as Year,
			sum(s.quantity*p.price) as total_sales
	FROM sales as s
	join 
	products as p
	on s.product_id=p.product_id
	join 
	stores as st
	on s.store_id = st.store_id
	GROUP BY 1,2,3
	ORDER BY 2,3
),
growth_rate
as
(
	SELECT
			store_name,
			total_sales as current_year_sales,
			Year,
			lag(total_sales,1) 	OVER(PARTITION BY store_name ORDER BY Year) AS last_year_sales
	FROM yearly_sales
)
SELECT
		store_name,
		Year,
		last_year_sales,
		current_year_sales,
		round((current_year_sales - last_year_sales)::numeric/last_year_sales::numeric*100,3) AS growth_ratio,
		CASE 
    WHEN round((current_year_sales - last_year_sales)::numeric/last_year_sales::numeric*100,3) > 0 THEN 'Positive'
    WHEN round((current_year_sales - last_year_sales)::numeric/last_year_sales::numeric*100,3) < 0 THEN 'Negative'
	END AS growth_trend
	from growth_rate
where last_year_sales is not null
and year <> 2024


-- Q.18 Calculate the correlation between product price and warranty claims for 
-- products sold in the last five years, segmented by price range.

select
		CASE
				WHEN p.price < 500 THEN 'Less Expenses Product'
				WHEN p.price BETWEEN 500 AND 1000 THEN 'Mid Range Product'
				ELSE 'Expensive Product'
				END AS price_segment,
		count(claim_id) as Total_claims
from warranty as w
LEFT JOIN
sales as s
ON w.sale_id=s.sale_id
JOIN
products as p
ON s.product_id=p.product_id
GROUP BY 1


-- Q.19 Identify the store with the highest percentage of "Paid Repaired" claims relative to total claims filed

WITH
paid_repaired AS
(
	SELECT
			s.store_id,
			COUNT(w.claim_id) AS paid_repaired
	from warranty as w
	LEFT JOIN
	sales as s
	ON w.sale_id=s.sale_id
	WHERE repair_status = 'Paid Repaired'
	GROUP BY s.store_id
	)
, total_repaired
AS
(
	SELECT
			s.store_id,
			COUNT(w.claim_id) AS Total_repaired
	from warranty as w
	LEFT JOIN
	sales as s
	ON w.sale_id=s.sale_id
	GROUP BY s.store_id
)
SELECT
		tr.store_id,
		st.store_name,
		pr.Paid_Repaired,
		tr.Total_repaired,
		round(pr.Paid_Repaired::numeric/tr.Total_repaired::numeric * 100,2) as percentage_paid_repaired
FROM 
total_repaired as tr
JOIN
paid_repaired as pr
ON tr.store_id=pr.store_id
JOIN
stores as st
ON tr.store_id = st.store_id


-- Q.20 Write a query to calculate the monthly running total of sales for each store
-- over the past four years and compare trends during this period.


WITH monthly_sales
AS
(SELECT 
	store_id,
	EXTRACT(YEAR FROM sale_date) as year,
	EXTRACT(MONTH FROM sale_date) as month,
	SUM(p.price * s.quantity) as total_revenue
FROM sales as s
JOIN 
products as p
ON s.product_id = p.product_id
GROUP BY 1, 2, 3
order by 1, 2,3
)
SELECT 
	store_id,
	month,
	year,
	total_revenue,
	SUM(total_revenue) over (PARTITION BY store_id ORDER BY year, month) as running_total
FROM monthly_sales

