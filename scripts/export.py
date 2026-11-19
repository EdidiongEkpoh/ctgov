import argparse
import csv 
import logging 
import os 
import sys 
from pathlib import Path 
from dotenv import load_dotenv

load_dotenv()
log = logging.getLogger("export")

TABLES = [
    "dim_trial", "dim_sponsor", "dim_condition_group", "dim_county", "bridge_trial_condition_group",
    "fct_results_reporting", "fct_trial_terminations", "fct_trial_sites", "fct_trial_status_history",
    "mart_county_burden_vs_sites", "meta_pipeline_status"
]
BATCH = 50000

def connect():
    import snowflake.connector

    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_BI_USER"],
        role=os.environ.get("SNOWFLAKE_BI_ROLE", "REPORTER"),
        warehouse=os.environ["SNOWFLAKE_WAREHOUSE"],
        database=os.environ["SNOWFLAKE_DATABASE"],
        authenticator="SNOWFLAKE_JWT",
        private_key_file=os.environ["SNOWFLAKE_BI_PRIVATE_KEY_PATH"],
        private_key_password=os.environ.get("SNOWFLAKE_BI_PRIVATE_KEY_PASSPHRASE") or None,
        application="ctgov-pipeline",
        session_parameters={"QUERY_TAG": "ctgov-pipeline:export"}
    )

def export_table(cur, schema, table, out_dir):
    cur.execute(f"SELECT * FROM {schema}.{table}")
    header = [c[0].lower() for c in cur.description]
    path = out_dir / f"{table}.csv"
    rows = 0
    with path.open('w', newline="", encoding="utf-8") as f:
        w = csv.writer(f, quoting=csv.QUOTE_NONNUMERIC)
        w.writerow(header)
        while batch := cur.fetchmany(BATCH):
            w.writerows(batch)
            rows += len(batch)
    log.info(f"{table}: {rows} rows -> {path}")
    return rows 

def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--out", default="exports")
    p.add_argument("--tables", default=",".join(TABLES))
    args = p.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

    tables = [t.strip().lower() for t in args.tables.split(",") if t.strip()]
    unknown = [t for t in tables if t not in TABLES]
    if unknown:
        raise SystemExit(f"Unknown table(s): {', '.join(unknown)}")
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    schema = os.environ.get("SNOWFLAKE_GOLD_SCHEMA", "GOLD")

    conn = connect()
    try:
        cur = conn.cursor()
        total = sum(export_table(cur, schema, t, out_dir) for t in tables)
    finally:
        conn.close()
    log.info(f"Done: {len(tables)} tables, {total} rows in {out_dir}")
    return 0

if __name__ == "__main__":
    sys.exit(main())