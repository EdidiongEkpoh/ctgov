import argparse
import datetime as dt
import sys
import time
import logging
import os
from utils import get_json, land, page_key, read_json, write_json

BASE = "https://clinicaltrials.gov/api/v2/studies"
SCOPE = "AREA[StudyType]INTERVENTIONAL AND AREA[StartDate]RANGE[2008-01-01, MAX]"
RAW_PREFIX = "source/studies"
STATE_KEY = "source/_state/ctgov_watermark.json"
MANIFEST_PREFIX = "source/_manifests"

log = logging.getLogger("ctgov")


def fetch_pages(params, page_size=1000, pause=0.5):
    token, page_no, seen, total = None, 0, 0, None
    while True:
        p = {**params, "pageSize": page_size, "format": "json"}
        if page_no == 0:
            p["countTotal"] = "true"
        if token:
            p["pageToken"] = token

        body = get_json(BASE, params=p)
        studies = body.get("studies", [])
        page_no += 1
        seen += len(studies)
        if page_no == 1:
            total = body.get("totalCount")
            log.info("Expecting %s studies", total)
        log.info("Page %d: %d studies (%d so far)", page_no, len(studies), seen)

        if studies:
            yield total, studies
        token = body.get("nextPageToken")
        if not token:
            log.info("Done: %d pages, %d studies", page_no, seen)
            return
        time.sleep(pause)

def read_watermark(bucket):
    state = read_json(bucket, STATE_KEY)
    return dt.date.fromisoformat(state['last_success_date']) if state else None

def build_filter(mode, since):
    if mode == "backfill":
        return SCOPE
    if since is None:
        raise SystemExit("No watermark found in S3. Run --mode backfill first.")
    start = since - dt.timedelta(days=1)
    return f"{SCOPE} AND AREA[LastUpdatePostDate]RANGE[{start:%Y-%m-%d}, MAX]"

def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--mode", choices=["backfill", "incremental"], required=True)
    parser.add_argument("--page-size", type=int, default=1000)
    parser.add_argument("--max-pages", type=int, default=None, help="stop early (for testing)")
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
    for key, value in os.environ.items():
        print(f"{key}: {value}")
    bucket = os.environ["CTGOV_S3_BUCKET"]
    run_ts = dt.datetime.now(dt.timezone.utc)
    run_prefix = f"{RAW_PREFIX}/ingest_date={run_ts:%Y-%m-%d}/run={run_ts:%H%M%S}"

    since = read_watermark(bucket) if args.mode == "incremental" else None
    params = {"filter.advanced": build_filter(args.mode, since)}
    log.info("Mode=%s filter=%s", args.mode, params["filter.advanced"])

    pages = records = 0
    total = None
    keys = []
    for page_no, (total, studies) in enumerate(fetch_pages(params, page_size=args.page_size), start=1):
        keys.append(land(studies, page_key(run_prefix, page_no), bucket))
        pages, records = page_no, records + len(studies)
        if args.max_pages and page_no >= args.max_pages:
            log.info("Stopping early at --max-pages=%d", args.max_pages)
            break
    
    finished = dt.datetime.now(dt.timezone.utc)
    manifest = {
        "mode": args.mode,
        "run_started_utc": run_ts.isoformat(),
        "run_finished_utc": finished.isoformat(),
        "duration_seconds": round((finished - run_ts).total_seconds(), 1),
        "filter": params["filter.advanced"],
        "api_total_count": total,
        "pages_written": pages,
        "records_written": records,
        "files_written": keys
    }
    write_json(bucket, f"{MANIFEST_PREFIX}/run={run_ts:%Y-%m-%dT%H%M%SZ}.json", manifest)

    if args.max_pages is None:
        write_json(bucket, STATE_KEY, {"last_success_date": f"{run_ts:%Y-%m-%d}",
                   "last_run_utc": run_ts.isoformat()})

        if total is not None and records != total:
            log.warning("Expected %d records, but only wrote %d", total, records)

    log.info("Done: %d pages, %d records, %d files", pages, records, len(keys))
    return 0

if __name__ == "__main__":
    sys.exit(main())