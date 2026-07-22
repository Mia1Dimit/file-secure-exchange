"""
Audit logging for the File Secure Exchange presign broker.

Every request — granted or denied — produces exactly one access-log record.
Written *before* a presigned URL is ever returned, per the plan's access
model: "Download access is logged in DynamoDB before the presigned URL is
returned."
"""

import os
import time
import uuid

import boto3

_dynamodb = boto3.resource("dynamodb")
_access_log_table = _dynamodb.Table(os.environ["ACCESS_LOG_TABLE"])


def write_access_log(
    *,
    document_id: str,
    session_id: str,
    principal_id: str,
    principal_role: str,
    action: str,
    result: str,
    source_ip: str,
    event_id: str | None = None,
    deny_reason: str | None = None,
) -> str:
    """
    Write one immutable access-log record.

    `result` is "granted" or "denied". `deny_reason` should be set whenever
    result == "denied" so the log is self-explanatory without needing to
    cross-reference application logs.
    """

    if event_id is None:
        event_id = str(uuid.uuid4())

    access_id = str(uuid.uuid4())
    now = int(time.time())

    item = {
        "access_id": access_id,
        "document_id": document_id,
        "session_id": session_id,
        "principal_id": principal_id,
        "principal_role": principal_role,
        "event_id": event_id,
        "action": action,
        "result": result,
        "source_ip": source_ip,
        "requested_at": now,
    }

    if result == "granted":
        item["granted_at"] = now
    if deny_reason:
        item["deny_reason"] = deny_reason

    _access_log_table.put_item(Item=item)
    return access_id
