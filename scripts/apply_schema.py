from pathlib import Path
from scripts.db import get_engine
from sqlalchemy import text

SCHEMA_PATH = Path(__file__).parent.parent / "sql" / "schema.sql"

engine = get_engine()

with open(SCHEMA_PATH, encoding="utf-8") as f:
    ddl = f.read()

with engine.begin() as conn:
    conn.execute(text(ddl))

print("Schema applied.")