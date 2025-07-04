import boto3
import os
from botocore.exceptions import ClientError

AWS_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")
AWS_BUCKET_NAME = os.getenv("AWS_BUCKET_NAME", "elbatt-chatbot-backup")

s3 = boto3.client(
    "s3",
    aws_access_key_id=AWS_ACCESS_KEY_ID,
    aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
)


def download_backup(file_name, bucket=AWS_BUCKET_NAME, dest_path="."):
    try:
        s3.download_file(bucket, file_name, os.path.join(dest_path, file_name))
        print(f"Backup lastet ned fra s3://{bucket}/{file_name} til {dest_path}")
    except ClientError as e:
        print(f"Feil ved nedlasting: {e}")


if __name__ == "__main__":
    backup_file = "backup_latest.zip"
    download_backup(backup_file, dest_path="/root/elbatt-chatbot-backup")
