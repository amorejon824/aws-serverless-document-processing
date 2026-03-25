import json
import boto3
import uuid
import os
from datetime import datetime

dynamodb = boto3.resource("dynamodb")
s3 = boto3.client("s3")

table = dynamodb.Table(os.environ["TABLE_NAME"])
UPLOAD_BUCKET = os.environ["UPLOAD_BUCKET"]

def lambda_handler(event, context):
    document_id = str(uuid.uuid4())

    item = {
        "document_id": document_id,
        "status": "uploaded",
        "created_at": datetime.utcnow().isoformat()
    }

    table.put_item(Item=item)

    presigned_url = s3.generate_presigned_url(
        ClientMethod="put_object",
        Params={
            "Bucket": UPLOAD_BUCKET,
            "Key": document_id
        },
        ExpiresIn=900
    )

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Document record created",
            "document_id": document_id,
            "upload_url": presigned_url
        })
    }