from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python_operator import PythonOperator
from clickhouse_driver import Client
import logging

# ClickHouse connection details
CLICKHOUSE_HOST = 'clickhouse-server'
CLICKHOUSE_PORT = 9000
CLICKHOUSE_DATABASE = 'ecomm'

# Store last processed timestamp function
def store_last_processed_timestamp(**kwargs):
    client = Client(host=CLICKHOUSE_HOST, port=CLICKHOUSE_PORT, database=CLICKHOUSE_DATABASE)

    query = """
    SELECT max(last_processed_ts) AS last_processed_ts FROM ecomm.daily_sales_stats_airflow
    """
    try:

        # Query to fetch the max last_processed_ts
        result = client.execute(query)
        last_processed_ts = result[0][0]
        
        if last_processed_ts is None:
            kwargs['ti'].xcom_push(key='last_processed_timestamp', value=datetime(2024, 1, 1).strftime('%Y-%m-%d %H:%M:%S'))
            logging.warning("last_processed_ts is None, storing intial value in XCOM...")

        else:
            # Update XCom with the new last_processed_ts
            kwargs['ti'].xcom_push(key='last_processed_timestamp', value=last_processed_ts.strftime('%Y-%m-%d %H:%M:%S'))
            logging.info(f"Updated last processed timestamp to {last_processed_ts}")

    except Exception as e:
        logging.error(f"Error: {e}")
    finally:
        client.disconnect()

# Metrics calculation function
def daily_metrics(**kwargs):
    client = Client(host=CLICKHOUSE_HOST, port=CLICKHOUSE_PORT, database=CLICKHOUSE_DATABASE)

    # Retrieve the last_processed_ts from XCOM
    last_processed_timestamp_str = kwargs['ti'].xcom_pull(task_ids='store_last_processed_timestamp_task', key='last_processed_timestamp')
    logging.info(f"last_processed_timestamp_str: {last_processed_timestamp_str }")

    last_processed_timestamp = datetime.strptime(last_processed_timestamp_str, '%Y-%m-%d %H:%M:%S')
    logging.info(f"Last processed timestamp: {last_processed_timestamp}")
    
    query = """
    INSERT INTO ecomm.daily_sales_stats_airflow
    SELECT
        toDate(oi.kafka_ts) AS date,
        MAX(oi.kafka_ts) AS last_processed_ts,
        COUNT(DISTINCT oi.order_id) AS total_orders,
        SUM(oi.quantity) AS total_items_sold,
        SUM(oi.price * oi.quantity) AS total_revenue,
        SUM(oi.cost_price * oi.quantity) AS total_cost,
        SUM(oi.price * oi.quantity) - SUM(oi.cost_price * oi.quantity) AS total_profit,
        CASE
            WHEN COUNT(DISTINCT oi.order_id) > 0 THEN SUM(oi.price * oi.quantity) / COUNT(DISTINCT oi.order_id)
            ELSE 0
        END AS average_order_value
    FROM
        demo_db.order_items AS oi
    LEFT JOIN
        demo_db.orders AS o ON oi.order_id = o.order_id
    WHERE
        o.status = 'Completed' and oi.kafka_ts > %(last_processed_timestamp)s
    GROUP BY
        toDate(oi.kafka_ts);
    """

    try:

        client.execute(query, {'last_processed_timestamp': last_processed_timestamp})
        logging.info(f"Metrics calculated and stored for data newer than {last_processed_timestamp}")

    except Exception as e:
        logging.error(f"Error during metrics calculation: {e}")
    finally:
        client.disconnect()


# Define the DAG
default_args = {
    'owner': 'data_engineer',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'daily_sales_metrics',
    default_args=default_args,
    description='Calculate and store daily sales metrics',
    schedule_interval='0 */6 * * *',
    catchup=False,
)

# task to store last_processed_ts
store_last_processed_timestamp_task = PythonOperator(
    task_id='store_last_processed_timestamp_task',
    python_callable=store_last_processed_timestamp,
    provide_context=True,
    dag=dag,
)

# task to calculate metrics
calculate_daily_metrics = PythonOperator(
    task_id='calculate_daily_metrics',
    python_callable=daily_metrics,
    provide_context=True,
    dag=dag,
)

store_last_processed_timestamp_task >> calculate_daily_metrics
