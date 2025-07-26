
-- Function to refresh the summary table
CREATE FUNCTION amount_summary_update()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
DELETE FROM summary;

-- insert data into summary table with tiers
-- Bronze: $25–$99, Silver: $100–$199, Gold: $200+
INSERT INTO summary(
SELECT
	customer_id, 
	CONCAT(first_name,' ',last_name) AS full_name,
	sum(amount) AS total_amount,
	'bronze' AS type
FROM detailed
GROUP BY customer_id, full_name
HAVING sum(amount) BETWEEN 25 and 99
UNION
SELECT
	customer_id,
    CONCAT(first_name,' ',last_name) AS full_name,
    sum(amount) AS total_amount,
    'silver' AS type
FROM detailed
GROUP BY customer_id, full_name
HAVING sum(amount) BETWEEN 100 and 199
UNION
SELECT
	customer_id, 
    CONCAT(first_name,' ',last_name) AS full_name,
    sum(amount) AS total_amount,
    'gold' AS type
FROM detailed
GROUP BY customer_id, full_name
HAVING sum(amount) >= 200
ORDER BY total_amount DESC
);
RETURN NEW;
END $$

-- Create detailed table to store data
CREATE TABLE detailed(
	customer_id INT, 
	first_name VARCHAR(30),
	last_name VARCHAR(30),
	email VARCHAR(90),
	amount DECIMAL(5,2),
	payment_date DATE
);

-- Create summary table with the membership model
CREATE TABLE summary(
	customer_id INT,
	full_name VARCHAR(60),
	total_amount DECIMAL(5,2),
	member_type VARCHAR (10)
);


-- Insert data
INSERT INTO detailed(
	customer_id,
	first_name,
	last_name,
	email,
	amount,
	payment_date
)
SELECT
	customer_id, 
	first_name,
	last_name,
	email,
	SUM(amount) AS total_amount,
	CAST(payment_date as date) 
FROM customer
JOIN payment USING (customer_id)
GROUP BY customer_id, payment_date
ORDER BY payment_date DESC;

-- Trigger to automatically update the summary table after inserting into detailed
CREATE TRIGGER update_summary
AFTER INSERT ON detailed
FOR EACH STATEMENT
EXECUTE PROCEDURE amount_summary_update()

-- Stored procedure to refresh the detailed payment data
CREATE PROCEDURE update_report()
LANGUAGE plpgsql
AS $$
BEGIN
DELETE FROM detailed;

-- Reload the detailed data from customer and payment tables
INSERT INTO detailed(
	customer_id,
	first_name,
	last_name,
	email,
	amount,
	payment_date
)
SELECT
	customer_id, 
	first_name,
	last_name,
	email,
	SUM(amount) AS total_amount,
	CAST(payment_date as date)
FROM customer
JOIN payment USING (customer_id)
GROUP BY customer_id, payment_date
ORDER BY payment_date DESC;
END $$
