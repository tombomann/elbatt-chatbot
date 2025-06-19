import boto3
import os
from botocore.exceptions import ClientError

AWS_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")
AWS_BUCKET_NAME = os.getenv("AWS_BUCKET_NAME", "elbatt-chatbot-backup")

s3 = boto3.client(
    "s3",
    aws_access_key_id=AWS_ACCESS_KEY_ID,
    aws_secret_access_key=AWS_SECRET_ACCESS_KEY
)

def upload_backup(file_path, bucket=AWS_BUCKET_NAME):
    try:
        s3.upload_file(file_path, bucket, os.path.basename(file_path))
        print(f"Backup lastet opp til s3://{bucket}/{os.path.basename(file_path)}")
    except ClientError as e:
        print(f"Feil ved opplasting: {e}")

if __name__ == "__main__":
    backup_file = "/root/elbatt-chatbot-backup/backup_latest.zip"
    upload_backup(backup_file)
