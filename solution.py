import sqlite3

conn = sqlite3.connect("data/comm_log.db")
cur = conn.cursor()

with open("queries/reconciliation.sql") as f:
    query = f.read()

cur.execute(query)
print(cur.fetchone())
conn.close()