# Serverless Document Processing System on AWS

I rebuilt a simple file upload application using a fully serverless architecture on AWS, focusing on scalability, cost-efficiency, and event-driven design.

## 🚀 Architecture Overview

This system replaces traditional backend file handling with a direct-to-S3 upload pattern using presigned URLs.

### Flow:
1. Client calls API to create a document
2. API (Lambda) generates a document ID and presigned S3 upload URL
3. Client uploads file directly to S3
4. S3 triggers processing Lambda
5. DynamoDB updates document status
6. Client retrieves status via API

## 🧱 AWS Services Used

- API Gateway (HTTP API)
- AWS Lambda (3 functions)
- Amazon DynamoDB
- Amazon S3 (event-driven)
- Amazon SNS (notifications)
- IAM (least privilege access)

## 🔥 Key Feature

### Presigned URL Upload
Instead of routing files through the backend:

Client → API → S3

This reduces backend load, improves scalability, and aligns with real-world cloud architecture patterns.

## 📸 Screenshots

(Add your screenshots here)

## 🧠 What I Learned

- Designing event-driven architectures
- Using presigned URLs for direct S3 uploads
- Structuring serverless applications
- Thinking like a Solutions Architect instead of just implementing features

## ⚙️ Deployment

```bash
terraform init
terraform plan
terraform apply
