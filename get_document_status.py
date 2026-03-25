import json
import boto3
import os

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])

def lambda_handler(event, context):
    document_id = event["pathParameters"]["id"]

    response = table.get_item(
        Key={"document_id": document_id}
    )

    item = response.get("Item")

    if not item:
        return {
            "statusCode": 404,
            "body": json.dumps({"message": "Document not found"})
        }

    return {
        "statusCode": 200,
        "body": json.dumps(item)
    }