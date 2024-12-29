import mysql.connector
import csv
import datetime

# Database Configuration
DB_CONFIG = {
    "host": "localhost",
    "port": 3355,
    "user": "root",
    "password": "rootpass",
    "database": "demo",
}

# Ingestion Function
def ingest_data_for_day(selected_date, orders_file, order_items_file):
    """
    Ingests data for a specific day from orders and order_items CSV files to MySQL.

    :param selected_date: Date in 'YYYY-MM-DD' format.
    :param orders_file: Path to the orders CSV file.
    :param order_items_file: Path to the order_items CSV file.
    """
    try:
        # Connect to MySQL
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor()


        # Read and Insert Orders
        with open(orders_file, "r") as orders_csv:
            orders_reader = csv.DictReader(orders_csv)
            for row in orders_reader:
                if row["updated_at"][:10] == selected_date:
                    cursor.execute(
                        """
                        INSERT INTO orders (order_id, customer_id, status, total_amount, created_at, updated_at)
                        VALUES (%s, %s, %s, %s, %s, %s)
                        ON DUPLICATE KEY UPDATE
                            status=VALUES(status),
                            total_amount=VALUES(total_amount),
                            updated_at=VALUES(updated_at)
                        """,
                        (
                            row["order_id"],
                            row["customer_id"],
                            row["status"],
                            float(row["total_amount"]),
                            row["created_at"],
                            row["updated_at"],
                        ),
                    )

        # Read and Insert Order Items
        with open(order_items_file, "r") as order_items_csv:
            order_items_reader = csv.DictReader(order_items_csv)
            for row in order_items_reader:
                if row["updated_at"][:10] == selected_date:
                    cursor.execute(
                        """
                        INSERT INTO order_items (order_item_id, order_id, product_id, quantity, price, cost_price, created_at, updated_at)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                        ON DUPLICATE KEY UPDATE
                            quantity=VALUES(quantity),
                            price=VALUES(price),
                            cost_price=VALUES(cost_price),
                            updated_at=VALUES(updated_at)
                        """,
                        (
                            row["order_item_id"],
                            row["order_id"],
                            row["product_id"],
                            int(row["quantity"]),
                            float(row["price"]),
                            float(row["cost_price"]),
                            row["created_at"],
                            row["updated_at"],
                        ),
                    )

        conn.commit()
        print(f"Data for {selected_date} successfully ingested into the database.")

    except mysql.connector.Error as err:
        print(f"Error: {err}")
        if conn:
            conn.rollback()

    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

# Example Usage
if __name__ == "__main__":
    selected_date = "2024-12-04"  # Replace with the desired date using format "yyyy-mm-dd"
    orders_file = "data/orders.csv" 
    order_items_file = "data/order_items.csv"  

    ingest_data_for_day(selected_date, orders_file, order_items_file)
