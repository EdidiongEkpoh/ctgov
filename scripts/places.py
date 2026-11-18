import argparse
import logging 
import os 
import sys 
import time 
import datetime as dt
from utils import get_json, land, page_key, write_json 

DEFAULT_DATASET_ID = "swc5-untb"
DEFAULT_RELEASE = "2025"

DEFAULT_MEASURES = [
    "DIABETES",
    "COPD",
    "CHD",
    "STROKE",
    "CASTHMA",
    "CANCER",
    "KIDNEY",
    "DEPRESSION",
    "OBESITY",
    "BPHIGH",
    "ARTHRITIS"
]

RAW_PREFIX = "source/cdc_places/county"
MANIFEST_PREFIX = "source/cdc_places/_manifests"

log = logging.getLogger("places")

def build_where(measures: list[str] | None) -> str | None:
    if not measures:
        return None 
    quoted = ",".join(f"'{m.upper()}'" for m in measures)
    return f"measureid in ({quoted})"

def count_rows(url: str, where: str | None, headers: dict) -> int | None:
    params = {"$select": "COUNT(*) AS n"}
    if where:
        params["$where"] = where
    rows = get_json(url, params=params, headers=headers)
    try:
        return int(rows[0]["n"])
    except (IndexError, KeyError, ValueError):
        log.warning(f"Could not read row count from {rows}")
        return None 

def fetch_pages(url, where: str | None, headers: dict, page_size: int=10000, pause: float = 0.25):
    offset, page_no = 0, 0
    while True:
        params = {"$limit": page_size, "$offset": offset, "$order": ":id"}
        if where:
            params["$where"] = where 

        rows = get_json(url, params=params, headers=headers)
        if not rows:
            return 
        page_no += 1
        offset += len(rows)
        log.info(f"Page {page_no}: {len(rows)} rows ({offset} so far)")
        yield rows 

        if len(rows) < page_size:
            return 
        time.sleep(pause)

def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dataset-id", default=DEFAULT_DATASET_ID)
    parser.add_argument("--release", default=DEFAULT_RELEASE, help="label used n the S3 path, e.g. 2025")
    parser.add_argument("--all-measures", action="store_true", help="ignore the measure filter")
    parser.add_argument("--page-size", type=int, default=10000)
    parser.add_argument("--max-pages", type=int, default=None, help="used to stop script early (for testing)")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

    bucket = os.environ["CTGOV_S3_BUCKET"]
    url = f"https://data.cdc.gov/resource/{args.dataset_id}.json"
    headers = {}
    if token := os.environ.get("SOCRATA_APP_TOKEN"):
        headers["X-App-Token"] = token 

    where = None if args.all_measures else build_where(DEFAULT_MEASURES)
    run_ts = dt.datetime.now(dt.timezone.utc)
    run_prefix = f"{RAW_PREFIX}.release={args.release}/ingest_date={run_ts:%Y-%m-%d}/run={run_ts:%H%M%S}"

    expected = count_rows(url, where, headers)
    log.info(f"Dataset={args.dataset_id} release={args.release} where={where} expecting={expected} rows")

    pages = records = 0
    keys = []
    for page_no, rows in enumerate(fetch_pages(url, where, headers, page_size=args.page_size), start=1):
        keys.append(land(rows, page_key(run_prefix, page_no), bucket))
        pages, records = page_no, records + len(rows)
        if args.max_pages and page_no >= args.max_pages:
            log.info(f"Stopping early at --max-pages={args.max_pages}")
            break 

    finished = dt.datetime.now(dt.timezone.utc)
    write_json(bucket, f"{MANIFEST_PREFIX}/run={run_ts:%Y-%m-%dT%H%M%SZ}.json", {
        "source": "cdc_places_county",
        "dataset_id": args.dataset_id, 
        "release": args.release,
        "run_started_utc": run_ts.isoformat(),
        "run_finished_utc": finished.isoformat(),
        "duration_seconds": round((finished - run_ts).total_seconds(), 1),
        "where": where,
        "api_row_count": expected,
        "pages_written": pages,
        "records_written": records,
        "files": keys
    })

    if args.max_pages is None and expected is not None and records != expected:
        log.warning(f"Wrote {records} rows but the API reported {expected}")

    log.info(f"Done: {pages} pages, {records} rows")
    return 0

if __name__ == "__main__":
    sys.exit(main())