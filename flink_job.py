from pyflink.table import EnvironmentSettings, TableEnvironment
import os

# Create a stream TableEnvironment
env_settings = EnvironmentSettings.in_streaming_mode()
table_env = TableEnvironment.create(env_settings)
config = table_env.get_config().get_configuration()

CURRENT_DIR = os.getcwd()

jar_files = [
    "my_jars/flink-sql-connector-kafka-3.3.0-1.20.jar",
    "my_jars/flink-sql-avro-confluent-registry-1.20.0.jar",
    "my_jars/flink-avro-1.20.0.jar"
]

jar_urls = [f"file:///{CURRENT_DIR}/{jar_file}" for jar_file in jar_files]

config.set_string("pipeline.jars", ";".join(jar_urls))
config.set_string("execution.checkpointing.interval", "60000")
config.set_string("parallelism.default", "2")
config.set_string("execution.checkpointing.mode", "EXACTLY_ONCE")
config.set_string("execution.checkpointing.checkpoints-directory", CURRENT_DIR)

# Define Kafka Source Tables for Orders and Order Items
table_env.execute_sql("""
    CREATE TABLE orders (
        after ROW<
            order_id STRING,
            customer_id STRING,
            status STRING,
            total_amount DECIMAL(10, 2),
            created_at STRING,
            updated_at STRING
        >,
        ts TIMESTAMP(3) METADATA FROM 'timestamp',
        WATERMARK FOR ts AS ts - INTERVAL '10' SECOND
    ) WITH (
        'connector' = 'kafka',
        'topic' = 'demo_db_master.demo.orders',
        'properties.bootstrap.servers' = 'kafka:9092',
        'value.format' = 'avro-confluent',
        'value.avro-confluent.schema-registry.url' = 'http://schema-registry:8081',
        'scan.startup.mode' = 'earliest-offset'
    )
""")

table_env.execute_sql("""
    CREATE TABLE order_items (
        after ROW<
            order_item_id STRING,
            order_id STRING,
            product_id STRING,
            quantity INT,
            price DECIMAL(10, 2),
            cost_price DECIMAL(10, 2),
            created_at STRING,
            updated_at STRING
        >,
        ts TIMESTAMP(3) METADATA FROM 'timestamp',
        WATERMARK FOR ts AS ts - INTERVAL '10' SECOND
    ) WITH (
        'connector' = 'kafka',
        'topic' = 'demo_db_master.demo.order_items',
        'properties.bootstrap.servers' = 'kafka:9092',
        'value.format' = 'avro-confluent',
        'value.avro-confluent.schema-registry.url' = 'http://schema-registry:8081',
        'scan.startup.mode' = 'earliest-offset'
    )
""")

print("Tables created")

# Define Transformation with Join and Aggregation
aggregated_metrics = table_env.sql_query("""
    SELECT 
        oi.ts,
        COUNT(DISTINCT oi.after.order_id) AS total_orders,
        SUM(oi.after.quantity) AS total_items_sold,
        SUM(oi.after.price * oi.after.quantity) AS total_revenue,
        SUM(oi.after.cost_price * oi.after.quantity) AS total_cost,
        SUM(oi.after.price * oi.after.quantity) - SUM(oi.after.cost_price * oi.after.quantity) AS total_profit,
        CASE 
            WHEN COUNT(DISTINCT oi.after.order_id) > 0 THEN SUM(oi.after.price * oi.after.quantity) / COUNT(DISTINCT oi.after.order_id)
            ELSE 0
        END AS average_order_value
    FROM 
        order_items oi
    LEFT JOIN 
        orders o ON oi.after.order_id = o.after.order_id
    WHERE 
        o.after.status = 'Completed'
    GROUP BY 
        oi.ts
""")

table_env.create_temporary_view("aggregated_metrics_view", aggregated_metrics)

# Define Kafka Sink Table for Daily Sales
table_env.execute_sql("""
    CREATE TABLE daily_sales (
        ts TIMESTAMP(3),
        total_orders BIGINT,
        total_items_sold BIGINT,
        total_revenue DECIMAL(10, 2),
        total_cost DECIMAL(10, 2),
        total_profit DECIMAL(10, 2),
        average_order_value DECIMAL(10, 2),
        PRIMARY KEY (`ts`) NOT ENFORCED
    ) WITH (
        'connector' = 'upsert-kafka',
        'topic' = 'daily_sales_metrics',
        'properties.bootstrap.servers' = 'kafka:9092',
        'key.format' = 'avro-confluent',
        'key.avro-confluent.schema-registry.url' = 'http://schema-registry:8081',
        'value.format' = 'avro-confluent',
        'value.avro-confluent.schema-registry.url' = 'http://schema-registry:8081'
    )
""")

print("Sink table created")

# Insert data from the "aggregated_metrics_view" into the "daily_sales" Kafka sink
table_env.execute_sql("""
    INSERT INTO daily_sales
    SELECT * FROM aggregated_metrics_view
""")

print("job started...")
