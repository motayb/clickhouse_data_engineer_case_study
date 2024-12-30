# Clickhouse Senior Data Engineer Case Study

## Scenario 1: Clickhouse & Kafka Challenge

``` mermaid
graph LR
    MySQL --> CDC[CDC via Debezium] --> Kafka --> a[ClickHouse Materialized Views]
```

### Steps:

1. **Start Docker Compose**
    ```bash
    docker compose up --build -d
    ```

2. **Open Conduktor UI**
    - URL: [http://localhost:8087](http://localhost:8087)
    - User: `admin@test.com`
    - Password: `admin`
    - Create Kafka cluster and set the schema registry in the new cluster.

3. **Start ClickHouse**
    ```bash
    docker exec -it clickhouse-webserver clickhouse-client
    ```

4. **Create Databases**
    - `kafka_db`
    - `demo_db`
    - `ecomm`

5. **Create Tables using Kafka Table Engine**
    - `products`
    - `orders`
    - `order_items`

6. **Create Tables using MergeTree Table Engine**

7. **Create Materialized Views**
    - Extract, transform, and feed the MergeTree tables.

8. **Ingest Data to MySQL**
    - Use `ingest_data_to_mysql.py` script to ingest data to `orders` and `order_items` MySQL tables.
    - Use CSV files inside the folder "data" and set `selected_date` for each ingestion.

9. **Query MergeTree Table**
    - Compare the received data with Kafka and MySQL data.

---

## Scenario 2: ClickHouse + Airflow Challenge

``` mermaid
graph LR
    MySQL --> CDC[CDC via Debezium] --> Kafka --> a[ClickHouse Materialized Views]
    a --> Airflow --> ClickHouse[ClickHouse Final Table]
```

### Steps:

1. **Create ClickHouse Summarized Table**
    - For Airflow transformation.

2. **Start Airflow UI**
    - URL: [http://localhost:8080](http://localhost:8080)

3. **Run Airflow DAG**

4. **Query ClickHouse Summarized Table**
    - Check the result.

5. **Ingest New Data to MySQL Tables**
    - Run Airflow DAG.
    - Query ClickHouse summarized table again.

---

## Scenario 3: Apache Flink Challenge

``` mermaid
graph LR
    MySQL --> CDC[CDC via Debezium] --> a[Kafka] --> Flink[Apache Flink]
    Flink --> b[Kafka] --> ClickHouse[ClickHouse Final Table]
```

### Steps:

1. **Start Flink Container**
    ```bash
    docker exec -it flink-jobmanager bash
    ```

2. **Copy `flink_job.py` to the Container**

3. **Run the Flink Job**
    ```bash
    flink run -py flink_job.py
    ```

4. **Start Flink UI**
    - URL: [http://localhost:8089](http://localhost:8089)
    - Monitor the job execution.

5. **Flink Job Output**
    - Feeds the daily sales metrics table to a new Kafka topic.

6. **Create ClickHouse Kafka Table, MergeTree Table, and Materialized View**
    - For the new Kafka topic created by the Flink job.

7. **Query the New Table**
    - Ingest new data and query again.

---

## Future Recommendations for ClickHouse Optimization

### Scaling Options

- **Horizontal Scaling**: Deploy ClickHouse shards and replicas to handle increased data volume and improve query concurrency.
- **Flink Parallelism**: Scale Flink jobs by adding more task slots and optimizing resource allocation in the cluster.

### Optimizations

- **Data Retention Policies**: Implement TTL (Time-to-Live) settings in ClickHouse to automatically clean up old, unused data.
- **Materialized Views**: Explore pre-aggregated views for complex queries to further reduce query times.
- **Compression**: Use ZSTD or LZ4 compression algorithms for MergeTree tables to minimize storage usage while maintaining read performance.
- **Partitioning**: Optimize table partitioning based on time intervals (e.g., monthly or daily) or business keys to reduce query scan ranges and improve performance.

### Data Types for Optimization

- **Low Cardinality**: Replace string columns with LowCardinality to save memory and improve query performance for columns with repetitive values.
- **Enum**: Use Enum8 or Enum16 data types for columns with a small, fixed set of values, reducing storage requirements and enhancing query efficiency.

### Deduplication Logic

- **ReplacingMergeTree**: Use the ReplacingMergeTree engine for deduplication by identifying and consolidating rows based on a unique identifier (e.g., a version column). This ensures that only the latest or most relevant data remains in the table.


