import datetime as dt
import gzip
import json
import logging
import time
import boto3
import requests
from botocore.exceptions import ClientError
from dotenv import load_dotenv
from tenacity import (
    before_sleep_log, retry, retry_if_exception, stop_after_attempt, wait_exponential
)


log = logging.getLogger("extract")
s3 = boto3.client("s3")
session = requests.Session()
session.headers.update({"User-Agent": "ctgov (portfolio project)"})


def is_retryable(exception):
    if isinstance(exception, (requests.ConnectionError, requests.Timeout)):
        return True
    if isinstance(exception, requests.HTTPError) and exception.response is not None:
        return exception.response.status_code == 429 or exception.response.status_code >= 500
    return False


@retry(
    retry=retry_if_exception(is_retryable),
    wait=wait_exponential(multiplier=1, min=2, max=60),
    stop=stop_after_attempt(6),
    before_sleep=before_sleep_log(log, logging.WARNING),
    reraise=True
)
def get_json(url, params=None, headers=None, timeout=60):
    r = session.get(url, params=params, headers=headers, timeout=timeout)
    if r.status_code == 429 and (wait := r.headers.get("Retry-After")):
        time.sleep(float(wait))
    r.raise_for_status()
    return r.json()

def land(records, key, bucket):
    ndjson = "\n".join(json.dumps(r, separators=(',', ':')) for r in records).encode("utf-8")
    s3.put_object(Bucket=bucket, Key=key, Body=gzip.compress(ndjson),
                  ContentType="application/json", ContentEncoding="gzip")
    return key


def write_json(bucket, key, payload):
    s3.put_object(Bucket=bucket, Key=key, Body=json.dumps(payload).encode("utf-8"),
                  ContentType="application/json")

def read_json(bucket, key):
    try:
        obj = s3.get_paginator
    except ClientError as e:
        if e.response['Error']['Code'] == 'NoSuchKey':
            return None
        else:
            raise
    return json.loads(obj['Body'].read())

def page_key(prefix, page_no):
    return f"{prefix}/page_no{page_no:05d}.json.gz"

