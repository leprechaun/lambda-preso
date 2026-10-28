import json
from urllib.parse import unquote_plus

import boto3

s3 = boto3.client("s3")


def handler(event, context):
    print(json.dumps(event))

    for record in event["Records"]:
        bucket = record["s3"]["bucket"]["name"]
        # Keys arrive URL-encoded in the event (spaces become '+', etc.)
        key = unquote_plus(record["s3"]["object"]["key"])

        obj = s3.get_object(Bucket=bucket, Key=key)
        body = obj["Body"].read().decode("utf-8", errors="replace")

        print(f"--- s3://{bucket}/{key} ---")
        print(body)
