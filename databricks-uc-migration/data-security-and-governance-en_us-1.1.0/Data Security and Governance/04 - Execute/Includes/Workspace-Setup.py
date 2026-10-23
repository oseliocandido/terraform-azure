# Databricks notebook source
# MAGIC %sql
# MAGIC USE CATALOG hive_metastore

# COMMAND ----------

# MAGIC %sql
# MAGIC CREATE SCHEMA IF NOT EXISTS finance;
# MAGIC CREATE SCHEMA IF NOT EXISTS sales;

# COMMAND ----------

# MAGIC %sql
# MAGIC GRANT USAGE,SELECT,READ_METADATA on SCHEMA finance TO `users`;
# MAGIC GRANT USAGE,SELECT,READ_METADATA on SCHEMA sales TO `users`;
# MAGIC GRANT USAGE,SELECT,READ_METADATA on SCHEMA default TO `users`;

# COMMAND ----------

# MAGIC %sql
# MAGIC CREATE TABLE IF NOT EXISTS sales.customers (
# MAGIC   customer_id INT,
# MAGIC   customer_name STRING,
# MAGIC   customer_email STRING,
# MAGIC   customer_region STRING,
# MAGIC   created_date DATE
# MAGIC );
# MAGIC MERGE INTO sales.customers
# MAGIC USING (
# MAGIC   SELECT * FROM VALUES
# MAGIC     (1, 'Acme Corp', 'contact@acme.com', 'North America', DATE '2022-01-10'),
# MAGIC     (2, 'Globex Inc', 'sales@globex.com', 'Europe', DATE '2022-02-15'),
# MAGIC     (3, 'Initech', 'info@initech.com', 'North America', DATE '2022-03-01'),
# MAGIC     (4, 'Umbrella Corp', 'support@umbrella.com', 'Asia', DATE '2022-03-20'),
# MAGIC     (5, 'Soylent Corp', 'hello@soylent.com', 'North America', DATE '2022-04-05'),
# MAGIC     (6, 'Hooli', 'biz@hooli.com', 'Europe', DATE '2022-04-18'),
# MAGIC     (7, 'Vehement Capital', 'contact@vehement.com', 'North America', DATE '2022-05-01'),
# MAGIC     (8, 'Stark Industries', 'sales@stark.com', 'North America', DATE '2022-05-12')
# MAGIC ) AS source 
# MAGIC ON customers.customer_id = source.col1
# MAGIC WHEN NOT MATCHED THEN
# MAGIC   INSERT (
# MAGIC     customer_id,
# MAGIC     customer_name,
# MAGIC     customer_email,
# MAGIC     customer_region,
# MAGIC     created_date
# MAGIC   )
# MAGIC   VALUES (
# MAGIC     source.col1,
# MAGIC     source.col2,
# MAGIC     source.col3,
# MAGIC     source.col4,
# MAGIC     source.col5
# MAGIC   );

# COMMAND ----------

# MAGIC %sql
# MAGIC CREATE TABLE IF NOT EXISTS sales.products (
# MAGIC   product_id INT,
# MAGIC   product_name STRING,
# MAGIC   product_category STRING,
# MAGIC   unit_price DECIMAL(10,2),
# MAGIC   active BOOLEAN
# MAGIC );
# MAGIC MERGE INTO sales.products
# MAGIC USING (
# MAGIC   SELECT * FROM VALUES
# MAGIC     (101, 'Analytics Platform', 'Software', 1200.00, true),
# MAGIC     (102, 'Data Warehouse License', 'Software', 2500.00, true),
# MAGIC     (103, 'Premium Support', 'Service', 500.00, true),
# MAGIC     (104, 'Training Package', 'Service', 800.00, true),
# MAGIC     (105, 'Legacy Connector', 'Software', 300.00, false)
# MAGIC ) AS source 
# MAGIC ON products.product_id = source.col1
# MAGIC WHEN NOT MATCHED THEN
# MAGIC   INSERT (
# MAGIC     product_id,
# MAGIC     product_name,
# MAGIC     product_category,
# MAGIC     unit_price,
# MAGIC     active
# MAGIC   )
# MAGIC   VALUES (
# MAGIC     source.col1,
# MAGIC     source.col2,
# MAGIC     source.col3,
# MAGIC     source.col4,
# MAGIC     source.col5
# MAGIC   );

# COMMAND ----------

# MAGIC %sql
# MAGIC CREATE TABLE IF NOT EXISTS sales.reps (
# MAGIC   sales_rep_id INT,
# MAGIC   sales_rep_name STRING,
# MAGIC   region STRING,
# MAGIC   hire_date DATE
# MAGIC );
# MAGIC
# MAGIC MERGE INTO sales.reps
# MAGIC USING (
# MAGIC   SELECT * FROM VALUES
# MAGIC     (201, 'Alex Morgan', 'North America', '2020-06-01'),
# MAGIC     (202, 'Jamie Lee', 'Europe', '2019-09-15'),
# MAGIC     (203, 'Chris Patel', 'Asia', '2021-02-10'),
# MAGIC     (204, 'Taylor Kim', 'North America', '2018-11-05')
# MAGIC ) AS source 
# MAGIC ON reps.sales_rep_id = source.col1
# MAGIC WHEN NOT MATCHED THEN
# MAGIC   INSERT (
# MAGIC     sales_rep_id,
# MAGIC     sales_rep_name,
# MAGIC     region,
# MAGIC     hire_date
# MAGIC   )
# MAGIC   VALUES (
# MAGIC     source.col1,
# MAGIC     source.col2,
# MAGIC     source.col3,
# MAGIC     source.col4
# MAGIC   );

# COMMAND ----------

# MAGIC %sql
# MAGIC CREATE TABLE IF NOT EXISTS sales.orders (
# MAGIC   order_id INT,
# MAGIC   customer_id INT,
# MAGIC   sales_rep_id INT,
# MAGIC   order_date DATE,
# MAGIC   order_status STRING,
# MAGIC   total_amount DECIMAL(12,2)
# MAGIC );
# MAGIC MERGE INTO sales.orders
# MAGIC USING (
# MAGIC   SELECT * FROM VALUES
# MAGIC     (1001, 1, 201, '2023-01-05', 'COMPLETED', 3700.00),
# MAGIC     (1002, 2, 202, '2023-01-12', 'COMPLETED', 2500.00),
# MAGIC     (1003, 3, 201, '2023-01-20', 'PENDING', 1200.00),
# MAGIC     (1004, 4, 203, '2023-02-02', 'COMPLETED', 1800.00),
# MAGIC     (1005, 5, 204, '2023-02-15', 'CANCELLED', 800.00),
# MAGIC     (1006, 6, 202, '2023-03-01', 'COMPLETED', 3000.00),
# MAGIC     (1007, 7, 201, '2023-03-10', 'COMPLETED', 1200.00),
# MAGIC     (1008, 8, 204, '2023-03-18', 'PENDING', 2500.00)
# MAGIC ) AS source 
# MAGIC ON orders.order_id = source.col1
# MAGIC WHEN NOT MATCHED THEN
# MAGIC   INSERT (
# MAGIC     order_id,
# MAGIC     customer_id,
# MAGIC     sales_rep_id,
# MAGIC     order_date,
# MAGIC     order_status,
# MAGIC     total_amount
# MAGIC   )
# MAGIC   VALUES (
# MAGIC     source.col1,
# MAGIC     source.col2,
# MAGIC     source.col3,
# MAGIC     source.col4,
# MAGIC     source.col5,
# MAGIC     source.col6
# MAGIC   );

# COMMAND ----------

# MAGIC %sql
# MAGIC CREATE TABLE IF NOT EXISTS sales.order_items (
# MAGIC   order_item_id INT,
# MAGIC   order_id INT,
# MAGIC   product_id INT,
# MAGIC   quantity INT,
# MAGIC   unit_price DECIMAL(10,2),
# MAGIC   line_total DECIMAL(12,2)
# MAGIC );
# MAGIC MERGE INTO sales.order_items
# MAGIC USING (
# MAGIC   SELECT * FROM VALUES
# MAGIC     (1, 1001, 101, 1, 1200.00, 1200.00),
# MAGIC     (2, 1001, 102, 1, 2500.00, 2500.00),
# MAGIC     (3, 1002, 102, 1, 2500.00, 2500.00),
# MAGIC     (4, 1003, 101, 1, 1200.00, 1200.00),
# MAGIC     (5, 1004, 104, 2, 800.00, 1600.00),
# MAGIC     (6, 1004, 103, 1, 500.00, 500.00),
# MAGIC     (7, 1005, 104, 1, 800.00, 800.00),
# MAGIC     (8, 1006, 102, 1, 2500.00, 2500.00),
# MAGIC     (9, 1006, 103, 1, 500.00, 500.00),
# MAGIC     (10, 1007, 101, 1, 1200.00, 1200.00),
# MAGIC     (11, 1008, 102, 1, 2500.00, 2500.00)
# MAGIC ) AS source 
# MAGIC ON order_items.order_item_id = source.col1
# MAGIC WHEN NOT MATCHED THEN
# MAGIC   INSERT (
# MAGIC     order_item_id,
# MAGIC     order_id,
# MAGIC     product_id,
# MAGIC     quantity,
# MAGIC     unit_price,
# MAGIC     line_total
# MAGIC   )
# MAGIC   VALUES (
# MAGIC     source.col1,
# MAGIC     source.col2,
# MAGIC     source.col3,
# MAGIC     source.col4,
# MAGIC     source.col5,
# MAGIC     source.col6
# MAGIC   );

# COMMAND ----------

# MAGIC %sql
# MAGIC CREATE TABLE IF NOT EXISTS finance.invoices (
# MAGIC   invoice_id INT,
# MAGIC   order_id INT,
# MAGIC   customer_id INT,
# MAGIC   invoice_date DATE,
# MAGIC   due_date DATE,
# MAGIC   invoice_amount DECIMAL(12,2),
# MAGIC   invoice_status STRING
# MAGIC );
# MAGIC MERGE INTO finance.invoices
# MAGIC USING (
# MAGIC   SELECT * FROM VALUES
# MAGIC     (5001, 1001, 1, '2023-01-06', '2023-02-05', 3700.00, 'PAID'),
# MAGIC     (5002, 1002, 2, '2023-01-13', '2023-02-12', 2500.00, 'PAID'),
# MAGIC     (5003, 1003, 3, '2023-01-21', '2023-02-20', 1200.00, 'OPEN'),
# MAGIC     (5004, 1004, 4, '2023-02-03', '2023-03-05', 2100.00, 'PAID'),
# MAGIC     (5005, 1006, 6, '2023-03-02', '2023-04-01', 3000.00, 'PAID'),
# MAGIC     (5006, 1008, 8, '2023-03-19', '2023-04-18', 2500.00, 'OPEN')
# MAGIC ) AS source 
# MAGIC ON invoices.invoice_id = source.col1
# MAGIC WHEN NOT MATCHED THEN
# MAGIC   INSERT (
# MAGIC     invoice_id,
# MAGIC     order_id,
# MAGIC     customer_id,
# MAGIC     invoice_date,
# MAGIC     due_date,
# MAGIC     invoice_amount,
# MAGIC     invoice_status
# MAGIC   )
# MAGIC   VALUES (
# MAGIC     source.col1,
# MAGIC     source.col2,
# MAGIC     source.col3,
# MAGIC     source.col4,
# MAGIC     source.col5,
# MAGIC     source.col6,
# MAGIC     source.col7
# MAGIC   );

# COMMAND ----------

# MAGIC %sql
# MAGIC CREATE TABLE IF NOT EXISTS finance.payments (
# MAGIC   payment_id INT,
# MAGIC   invoice_id INT,
# MAGIC   payment_date DATE,
# MAGIC   payment_amount DECIMAL(12,2),
# MAGIC   payment_method STRING
# MAGIC );
# MAGIC MERGE INTO finance.payments
# MAGIC USING (
# MAGIC   SELECT * FROM VALUES
# MAGIC     (7001, 5001, '2023-01-20', 3700.00, 'WIRE'),
# MAGIC     (7002, 5002, '2023-01-25', 2500.00, 'CREDIT_CARD'),
# MAGIC     (7003, 5004, '2023-02-18', 2100.00, 'WIRE'),
# MAGIC     (7004, 5005, '2023-03-15', 3000.00, 'ACH')
# MAGIC ) AS source 
# MAGIC ON payments.payment_id = source.col1
# MAGIC WHEN NOT MATCHED THEN
# MAGIC   INSERT (
# MAGIC     payment_id,
# MAGIC     invoice_id,
# MAGIC     payment_date,
# MAGIC     payment_amount,
# MAGIC     payment_method
# MAGIC   )
# MAGIC   VALUES (
# MAGIC     source.col1,
# MAGIC     source.col2,
# MAGIC     source.col3,
# MAGIC     source.col4,
# MAGIC     source.col5
# MAGIC   );

# COMMAND ----------

# MAGIC %sql
# MAGIC CREATE TABLE IF NOT EXISTS finance.expenses (
# MAGIC   expense_id INT,
# MAGIC   expense_date DATE,
# MAGIC   expense_category STRING,
# MAGIC   cost_center STRING,
# MAGIC   amount DECIMAL(12,2),
# MAGIC   description STRING
# MAGIC );
# MAGIC MERGE INTO finance.expenses
# MAGIC USING (
# MAGIC   SELECT * FROM VALUES
# MAGIC     (9001, '2023-01-05', 'Cloud Infrastructure', 'IT', 1800.00, 'Databricks compute charges'),
# MAGIC     (9002, '2023-01-15', 'Travel', 'Sales', 1200.00, 'Customer onsite visit'),
# MAGIC     (9003, '2023-02-01', 'Marketing', 'Marketing', 2500.00, 'Conference sponsorship'),
# MAGIC     (9004, '2023-02-20', 'Software Licenses', 'IT', 900.00, 'BI tool licenses'),
# MAGIC     (9005, '2023-03-10', 'Training', 'HR', 1500.00, 'Sales enablement training')
# MAGIC ) AS source 
# MAGIC ON expenses.expense_id = source.col1
# MAGIC WHEN NOT MATCHED THEN
# MAGIC   INSERT (
# MAGIC     expense_id,
# MAGIC     expense_date,
# MAGIC     expense_category,
# MAGIC     cost_center,
# MAGIC     amount,
# MAGIC     description
# MAGIC   )
# MAGIC   VALUES (
# MAGIC     source.col1,
# MAGIC     source.col2,
# MAGIC     source.col3,
# MAGIC     source.col4,
# MAGIC     source.col5,
# MAGIC     source.col6
# MAGIC   );

# COMMAND ----------

# MAGIC %sql
# MAGIC CREATE VIEW IF NOT EXISTS finance.invoice_balances AS
# MAGIC SELECT
# MAGIC   i.invoice_id,
# MAGIC   i.invoice_amount,
# MAGIC   COALESCE(SUM(p.payment_amount), 0) AS paid_amount,
# MAGIC   i.invoice_amount - COALESCE(SUM(p.payment_amount), 0) AS outstanding_amount
# MAGIC FROM finance.invoices i
# MAGIC LEFT JOIN finance.payments p
# MAGIC   ON i.invoice_id = p.invoice_id
# MAGIC GROUP BY
# MAGIC   i.invoice_id,
# MAGIC   i.invoice_amount;