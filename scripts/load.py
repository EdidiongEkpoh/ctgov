import argparse
import logging 
import os 
import sys 
from dataclasses import dataclass
log = logging.getLogger("load.copy_into_staging")

STAGE = "CTGOV.STAGING.S3_CTGOV"
FILE_PATTERN = ".*[.]json[.]gz"

@dataclass(frozen=True)
class Target:
    name: str 
    table: str 
    stage_path: str 

TARGETS = {
    "ctgov": Target("ctgov", "CTGOV.STAGING.CTGOV_STUDIES", "studies/"),
    "places": Target("places", "CTGOV.STAGING.CDC_PLACES_COUNTY", "county/")
}

def copy_sql(t):
    return f"""COPY INTO {t.table} (record, file_name) 
            FROM ( 
                SELECT $1, METADATA$FILENAME 
                FROM @{STAGE}/{t.stage_path} 
                 )
            PATTERN = '{FILE_PATTERN} 
            ON_ERROR = ABORT_STATEMENT
            """.strip()

def purge_sql(t, days):
    return (
        f"DELETE FROM {t.table}"
        f"WHERE loaded_at < DATEADD(day, -{int(days)}, CURRENT_TIMESTAMP())"
    )

def summarize_copy(rows, columns):
    files = (dict(zip(columns, r)) for r in rows)
    loaded = [f for f in files if str(f.get("status", "")).upper() in ("LOADED", "PARTIALLY_LOADED")]
    return {
        "files_loaded": len(loaded),
        "rows_loaded": sum(int(f.get("rows_loaded") or 0) for f in loaded),
        "errors_seen": sum(int(f.get("errors_seen") or 0) for f in loaded),
        "statuses": sorted({str(f.get("status")) for f in files})
    }

def connect():
    import snowflake.connector
    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_LOADER_USER"],
        role=os.environ["SNOWFLAKE_LOADER_ROLE"],
        warehouse=os.environ("SNOWFLAKE_WAREHOUSE"),
        database=os.environ["SNOWFLAKE_DATABASE"],
        authenticator="SNOWFLAKE_JWT",
        private_key_file=os.environ["SNOWFLAKE_LOADER_PRIVATE_KEY_PATH"],
        private_key_password=os.environ.get("SNOWFLAKE_LOADER_PRIVATE_KEY_PASSPHRASE") or None,
        application="ctgov-pipeline", 
        session_parameters={"QUERY_TAG": "ctgov-pipeline:load"}
    )

def run_copy(cur, t):
    sql = copy_sql(t)
    log.info(f"COPY INTO {t.table} FROM @{STAGE}/{t.stage_path}")
    cur.execute(sql)
    columns = [c[0].lower() for c in cur.description]
    summary = summarize_copy(cur.fetchall(), columns)
    log.info(f"{t.name}: {summary["files_loaded"]} files, {summary["rows_loaded"]} rows loaded ({", ".join(summary["statuses"])})")
    return summary 

def run_purge(cur, t, days):
    cur.execute(purge_sql(t, days))
    deleted = cur.rowcount or 0
    log.info(f"{t.name}: purged {deleted} STAGING rows older than {days} days")
    return deleted 

def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--tables", default="ctgov,places", help=f"comma-separated subset of: {', '.join(TARGETS)}")
    parser.add_argument("--purge-days", type=int, default=14)
    parser.add_argument("--no-purge", action="store_true")
    parser.add_argument("--dry-run", action="store_true", help="print SQL without connecting")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

    names = [n.strip() for n in args.tables.split(",") if n.strip()]
    unknown = [n for n in names if n not in TARGETS]
    if unknown:
        raise SystemExit(f"Unknown tables(s): {', '.join(unknown)}. Choose from {', '.join(TARGETS)}")
    targets = [TARGETS[n] for n in names]

    if args.dry_run:
        for t in targets:
            print(copy_sql(t), end=";\n\n")
            if not args.no_purge:
                print(purge_sql(t, args.purge_days), end=";\n\n")
        return 0 

    conn = connect() 
    try:
        cur = conn.cursor()
        totals = {t.name: run_copy(cur, t) for t in targets}
        if not args.no_purse:
            for t in targets:
                run_purge(cur, t, args.purge_days)
    finally:
        conn.close()

    errors = sum(s["errors_seen"] for s in totals.values())
    if errors:
        log.error(f"COPY reported {errors} errors")
        return 1
    log.info("Done: %s", ", ".join(f"{k}={v['rows_loaded']} rows" for k, v in totals.items()))
    return 0

if __name__ == "__main__":
    sys.exit(main())