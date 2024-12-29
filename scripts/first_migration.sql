-- Drop database if it exists, so everything is recreated each time
DROP DATABASE IF EXISTS demo;

-- Create the database
CREATE DATABASE demo;

-- Switch to the new database
USE demo;

-- Create a migration history table to track if the migration has been applied
CREATE TABLE IF NOT EXISTS migration_history (
    id INT PRIMARY KEY AUTO_INCREMENT,
    migration_name VARCHAR(255) NOT NULL,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert a record indicating this migration was applied (only if it doesn't already exist)
INSERT INTO
    migration_history (migration_name)
SELECT
    'initial_setup'
WHERE
    NOT EXISTS (
        SELECT
            1
        FROM
            migration_history
        WHERE
            migration_name = 'initial_setup'
    );

-- Drop the user if it exists to avoid conflicts, then recreate
DROP USER IF EXISTS 'debezium' @'%';

-- Create user 'debezium' with password 'debezium_pass'
CREATE USER 'debezium' @'%' IDENTIFIED BY 'debezium_pass';

-- Grant necessary permissions to 'debezium' user
GRANT
SELECT
,
    RELOAD,
    SHOW DATABASES,
    REPLICATION SLAVE,
    REPLICATION CLIENT ON *.* TO 'debezium' @'%';

-- Apply the permission changes
FLUSH PRIVILEGES;

-- Drop tables if they exist to recreate each time the script runs
DROP TABLE IF EXISTS products;

DROP TABLE IF EXISTS orders;

DROP TABLE IF EXISTS order_items;

-- Create the 'products' table
CREATE TABLE products (
    product_id VARCHAR(255) NOT NULL PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    cost_price DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create the 'orders' table
CREATE TABLE orders (
    order_id VARCHAR(255) NOT NULL PRIMARY KEY,
    customer_id VARCHAR(255) NOT NULL,
    status VARCHAR(255) NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create the 'order_items' table with a foreign key to 'orders' and 'products'
CREATE TABLE order_items (
    order_item_id VARCHAR(255) NOT NULL PRIMARY KEY,
    order_id VARCHAR(255) NOT NULL,
    product_id VARCHAR(255) NOT NULL,
    quantity INT NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    cost_price DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE RESTRICT
);

-- Insert data to the 'products' table
INSERT INTO products (product_id, product_name, price, cost_price, created_at, updated_at)
VALUES
    ('PROD-101', 'Multivitamins', 15.16, 10.61, '2024-02-21', '2024-02-21'),
    ('PROD-102', 'Vitamin C', 91.59, 64.11, '2024-10-11', '2024-10-11'),
    ('PROD-103', 'Vitamin D3', 64.46, 45.12, '2024-08-03', '2024-08-03'),
    ('PROD-104', 'Omega-3', 29.64, 20.75, '2024-08-13', '2024-08-13'),
    ('PROD-105', 'Probiotics', 17.19, 12.03, '2024-08-25', '2024-08-25'),
    ('PROD-106', 'Vitamin B12', 91.59, 64.11, '2024-01-24', '2024-01-24'),
    ('PROD-107', 'Magnesium', 11.28, 7.90, '2024-01-22', '2024-01-22'), 
    ('PROD-108', 'Zinc', 23.74, 16.62, '2024-08-02', '2024-08-02'),
    ('PROD-109', 'Collagen', 20.14, 14.10, '2024-04-02', '2024-04-02'), 
    ('PROD-110', 'Protein', 37.04, 25.93, '2024-11-15', '2024-11-15');
