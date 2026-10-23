"""訪問者カウンター API

- POST: カウントを 1 増やして、増やした後の値を返す
- GET : 今のカウントを返す（増やさない）
"""

import json
import os

import boto3

TABLE_NAME = os.environ["TABLE_NAME"]
COUNTER_KEY = {"pk": "visitors"}

# ハンドラーの外で作っておくと、Lambda が再利用されたときに接続を使い回せる
table = boto3.resource("dynamodb").Table(TABLE_NAME)


def handler(event, context):
    method = event.get("requestContext", {}).get("http", {}).get("method", "GET")

    if method == "POST":
        count = increment()
    elif method == "GET":
        count = current()
    else:
        return response(405, {"message": "Method Not Allowed"})

    return response(200, {"count": count})


def increment() -> int:
    # ADD は「読んで +1 して書く」をDynamoDB側で1回で行う（同時アクセスでも数がずれない）
    # count は DynamoDB の予約語なので #c という別名で指定する
    result = table.update_item(
        Key=COUNTER_KEY,
        UpdateExpression="ADD #c :one",
        ExpressionAttributeNames={"#c": "count"},
        ExpressionAttributeValues={":one": 1},
        ReturnValues="UPDATED_NEW",
    )
    return int(result["Attributes"]["count"])


def current() -> int:
    result = table.get_item(Key=COUNTER_KEY)
    return int(result.get("Item", {}).get("count", 0))


def response(status: int, body: dict) -> dict:
    # CORS のヘッダーは関数URLの設定で自動的に付くので、ここでは付けない（二重になるとエラーになる）
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }
