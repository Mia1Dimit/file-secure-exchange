"""
Document registry and presigned URL generation for the File Secure Exchange
presign broker.

Handles the `documents` DynamoDB table and S3 presigning. Deliberately does
not touch the AI classifier or SNS review routing — that's Phase 2, wired
asynchronously off EventBridge, per ADR-0002 (keeps this Lambda's blast
radius small and its behavior easy to reason about on its own).
"""

import os
import time
import uuid

import boto3
from botocore.config import Config

_dynamodb = boto3.resource("dynamodb")
_documents_table = _dynamodb.Table(os.environ["DOCUMENTS_TABLE"])

_bucket = os.environ["DOCUMENTS_BUCKET"]
_presign_expiry = int(os.environ.get("PRESIGN_EXPIRY_SECONDS", "300"))

# SigV4 + virtual-hosted addressing avoids surprises with the presigned URL
# host once this leaves eu-central-1's default resolver behavior.
_s3 = boto3.client(
    "s3",
    config=Config(signature_version="s3v4", s3={"addressing_style": "virtual"}),
)


def create_document_record(
    *, session_id: str, owner_id: str, uploader_id: str, receiver_id: str, filename: str
) -> dict:
    """
    Register a new document before issuing an upload URL. classification_status
    starts as "pending" — Phase 2's AI classifier Lambda updates this
    asynchronously once the object lands in S3 and EventBridge fires.
    """
    document_id = str(uuid.uuid4())
    now = int(time.time())
    s3_key = f"{session_id}/{document_id}/{filename}"

    item = {
        "document_id": document_id,
        "session_id": session_id,
        "owner_id": owner_id,
        "uploader_id": uploader_id,
        "receiver_id": receiver_id,
        "s3_key": s3_key,
        "document_type": "unknown",
        "classification_status": "pending",
        "encryption_type": "SSE-S3",
        "created_at": now,
        "updated_at": now,
    }
    _documents_table.put_item(Item=item)
    return item


def get_document(document_id: str) -> dict | None:
    response = _documents_table.get_item(Key={"document_id": document_id})
    return response.get("Item")


def generate_upload_url(s3_key: str, content_type: str) -> str:
    return _s3.generate_presigned_url(
        "put_object",
        Params={"Bucket": _bucket, "Key": s3_key, "ContentType": content_type},
        ExpiresIn=_presign_expiry,
    )


def generate_download_url(s3_key: str) -> str:
    return _s3.generate_presigned_url(
        "get_object",
        Params={"Bucket": _bucket, "Key": s3_key},
        ExpiresIn=_presign_expiry,
    )
