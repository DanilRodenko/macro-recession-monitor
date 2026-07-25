import os
import psycopg2
from dotenv import load_dotenv

load_dotenv()

conn = psycopg2.connect(
    dbname="postgres",
    user=os.getenv("DB_USER"),
    password=os.getenv("DB_PASSWORD"),
    host=os.getenv("DB_HOST"),
    port=os.getenv("DB_PORT"),
)
conn.autocommit = True
cur = conn.cursor()
cur.execute(f"CREATE DATABASE {os.getenv('DB_NAME')};")
cur.close()
conn.close()
print("Database created.")