-- Databases creation

CREATE DATABASE kafka_db;
CREATE DATABASE demo_db;
CREATE DATABASE ecomm;

-- Kafka engine tables creation

CREATE TABLE kafka_db.kafka_products
(
 after Tuple(product_id String, product_name String, price DECIMAL(10, 2), cost_price DECIMAL(10, 2), created_at String, updated_at String)
)
ENGINE = Kafka()
SETTINGS
kafka_broker_list = 'kafka:9092',
kafka_topic_list = 'demo_db_master.demo.products',
kafka_group_name = 'ch_group1',
kafka_format = 'AvroConfluent',
format_avro_schema_registry_url='http://schema-registry:8081';

CREATE TABLE kafka_db.kafka_orders
(
 after Tuple(order_id String, customer_id String, status String, total_amount DECIMAL(10, 2), created_at String, updated_at String)
)
ENGINE = Kafka()
SETTINGS
kafka_broker_list = 'kafka:9092',
kafka_topic_list = 'demo_db_master.demo.orders',
kafka_group_name = 'ch_group1',
kafka_format = 'AvroConfluent',
format_avro_schema_registry_url='http://schema-registry:8081';


CREATE TABLE kafka_db.kafka_order_items
(
 after Tuple(order_item_id String, order_id String, product_id String, quantity UInt32, price DECIMAL(10, 2), cost_price DECIMAL(10, 2), created_at String, updated_at String)
)
ENGINE = Kafka()
SETTINGS
kafka_broker_list = 'kafka:9092',
kafka_topic_list = 'demo_db_master.demo.order_items',
kafka_group_name = 'ch_group1',
kafka_format = 'AvroConfluent',
format_avro_schema_registry_url='http://schema-registry:8081';


-- MergeTree tables creation

CREATE TABLE demo_db.products
(
    product_id String,
    product_name String,
    price DECIMAL(10, 2),
    cost_price DECIMAL(10, 2),
    created_at DateTime,
    updated_at DateTime,
    kafka_ts DateTime64(3) DEFAULT now()
)
ENGINE = MergeTree
ORDER BY product_id
SETTINGS index_granularity = 8192;

CREATE TABLE demo_db.orders
(
    order_id String,
    customer_id String,
    status String,
    total_amount DECIMAL(10, 2),
    created_at DateTime,
    updated_at DateTime,
	kafka_ts DateTime64(3) DEFAULT now() 
)
ENGINE = MergeTree
ORDER BY (toDate(created_at), order_id)
SETTINGS index_granularity = 8192;

CREATE TABLE demo_db.order_items
(
    order_item_id String,
    order_id String,
    product_id String,
    quantity UInt32,
    price DECIMAL(10, 2),
    cost_price DECIMAL(10, 2),
    created_at DateTime,
    updated_at DateTime,
    kafka_ts DateTime64(3) DEFAULT now()
)
ENGINE = MergeTree
ORDER BY (toDate(created_at), order_id)
SETTINGS index_granularity = 8192;


-- Materialized Views to extract/transform Kafka table data into MergeTree tables

CREATE MATERIALIZED VIEW kafka_db.kafka_products_mv TO demo_db.products
(
    product_id String,
    product_name String,
    price DECIMAL(10, 2),
    cost_price DECIMAL(10, 2),
    created_at DateTime,
    updated_at DateTime
)
AS SELECT
    tupleElement(after, 1) AS product_id,
    tupleElement(after, 2) AS product_name,
    tupleElement(after, 3) AS price,
    tupleElement(after, 4) AS cost_price,
    toDateTime(replaceAll(replaceAll(after.5, 'T', ' '), 'Z', '')) AS created_at,
    toDateTime(replaceAll(replaceAll(after.6, 'T', ' '), 'Z', '')) AS updated_at
FROM kafka_db.kafka_products;

CREATE MATERIALIZED VIEW kafka_db.kafka_orders_mv TO demo_db.orders
(
    order_id String,
    customer_id String,
    status String,
    total_amount DECIMAL(10, 2),
    created_at DateTime,
    updated_at DateTime
)
AS SELECT
    tupleElement(after, 1) AS order_id,
    tupleElement(after, 2) AS customer_id,
    tupleElement(after, 3) AS status,
	tupleElement(after, 4) AS total_amount,
    toDateTime(replaceAll(replaceAll(after.5, 'T', ' '), 'Z', '')) AS created_at,
    toDateTime(replaceAll(replaceAll(after.6, 'T', ' '), 'Z', '')) AS updated_at
FROM kafka_db.kafka_orders;

CREATE MATERIALIZED VIEW kafka_db.kafka_order_items_mv TO demo_db.order_items
(
    order_item_id String,
    order_id String,
    product_id String,
    quantity UInt32,
    price DECIMAL(10, 2),
    cost_price DECIMAL(10, 2),
    created_at DateTime,
    updated_at DateTime
)
AS SELECT
    tupleElement(after, 1) AS order_item_id,
    tupleElement(after, 2) AS order_id,
    tupleElement(after, 3) AS product_id,
    tupleElement(after, 4) AS quantity,
	tupleElement(after, 5) AS price,
	tupleElement(after, 6) AS cost_price,
    toDateTime(replaceAll(replaceAll(after.7, 'T', ' '), 'Z', '')) AS created_at,
    toDateTime(replaceAll(replaceAll(after.8, 'T', ' '), 'Z', '')) AS updated_at
FROM kafka_db.kafka_order_items;


-- ClickHouse summarized table to be feeded by Airflow

CREATE TABLE ecomm.daily_sales_stats_airflow (
    kafka_ts Date,
    last_processed_ts DateTime64(3),
    total_orders UInt64,
    total_items_sold UInt64,
    total_revenue Decimal(10, 2),
    total_cost Decimal(10, 2),
    total_profit Decimal(10, 2),
    average_order_value Decimal(10, 2),
) ENGINE = AggregatingMergeTree()
ORDER BY kafka_ts
PARTITION BY toMonth(kafka_ts);


-- ClickHouse daily_sales table to be feeded by Flink

CREATE TABLE kafka_db.daily_sales_metrics_kafka_flink
(
    ts DateTime64(3),
    total_orders UInt64,
    total_items_sold UInt64,
    total_revenue Decimal(10, 2),
    total_cost Decimal(10, 2),
    total_profit Decimal(10, 2),
    average_order_value Decimal(10, 2)
)
ENGINE = Kafka()
SETTINGS
kafka_broker_list = 'kafka:9092',
kafka_topic_list = 'daily_sales_metrics_v3',
kafka_group_name = 'ch_group2',
kafka_format = 'AvroConfluent',
format_avro_schema_registry_url='http://schema-registry:8081';


CREATE TABLE ecomm.daily_sales_metrics_flink
(
    ts Date,
    total_orders UInt64,
    total_items_sold UInt64,
    total_revenue Decimal(10, 2),
    total_cost Decimal(10, 2),
    total_profit Decimal(10, 2),
    average_order_value Decimal(10, 2)
)
ENGINE = AggregatingMergeTree()
ORDER BY ts
PARTITION BY toMonth(ts);

CREATE MATERIALIZED VIEW kafka_db.daily_sales_metrics_kafka_flink_mv TO ecomm.daily_sales_metrics_flink
(
    ts Date,
    total_orders UInt64,
    total_items_sold UInt64,
    total_revenue Decimal(10, 2),
    total_cost Decimal(10, 2),
    total_profit Decimal(10, 2),
    average_order_value Decimal(10, 2)
)
AS SELECT
    toDate(ts) as ts,
    total_orders,
    total_items_sold,
    total_revenue,
    total_cost,
    total_profit,
    average_order_value
FROM kafka_db.daily_sales_metrics_kafka_flink;

