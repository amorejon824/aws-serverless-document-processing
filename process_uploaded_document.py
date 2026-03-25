import boto3
import os
from datetime import datetime

dynamodb = boto3.resource("dynamodb")
sns = boto3.client("sns")

table = dynamodb.Table(os.environ["TABLE_NAME"])
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]

def lambda_handler(event, context):
    for record in event["Records"]:
        key = record["s3"]["object"]["key"]
        document_id = key.split("/")[-1]

        table.update_item(
            Key={"document_id": document_id},
            UpdateExpression="SET #s = :s, processed_at = :t",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={
                ":s": "completed",
                ":t": datetime.utcnow().isoformat()
            }
        )

        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Message=f"Document {document_id} processed successfully"
        )

    return {"statusCode": 200}