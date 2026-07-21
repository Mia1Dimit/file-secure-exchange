"""
File Secure Exchange — presign broker Lambda.

Entry point: handler(event, context).

Supports two input shapes so this can be built and tested *before* API
Gateway exists (API Gateway wiring is next):

1. API Gateway REST proxy integration (has "httpMethod"). Principal
   identity comes from the Cognito authorizer claims at
   event["requestContext"]["authorizer"]["claims"].

2. Direct invoke, for testing today via `aws lambda invoke`:
       {
         "action": "upload" | "download",
         "principal_id": "...",
         "principal_role": "sender" | "receiver",
         "source_ip": "test-invoke",
         ...action-specific fields (see upload()/download() below)
       }

Both paths converge on the same upload()/download() logic and the same
audit trail — there is exactly one code path for "is this allowed", not
one for API Gateway and a separate untested one for direct calls.
"""

import json

from audit import write_access_log
from documents import create_document_record, generate_download_url, generate_upload_url, get_document


class BrokerError(Exception):
    def __init__(self, status_code: int, message: str):
        super().__init__(message)
        self.status_code = status_code
        self.message = message


def handler(event, context):
    try:
        request = _normalize_event(event)
        action = request["action"]

        if action == "upload":
            result = upload(request)
        elif action == "download":
            result = download(request)
        else:
            raise BrokerError(400, f"unknown action: {action}")

        return _response(200, result)

    except BrokerError as err:
        return _response(err.status_code, {"error": err.message})
    except KeyError as err:
        return _response(400, {"error": f"missing required field: {err}"})


def upload(request: dict) -> dict:
    """
    Register a document and issue a presigned PUT URL. Only `sender`
    principals may upload, and only as themselves — a sender cannot issue
    an upload on behalf of a different uploader_id.
    """
    principal_id = request["principal_id"]
    principal_role = request["principal_role"]
    session_id = request["session_id"]
    uploader_id = request["uploader_id"]

    if principal_role != "sender":
        write_access_log(
            document_id="n/a",
            session_id=session_id,
            principal_id=principal_id,
            principal_role=principal_role,
            action="upload_presign_request",
            result="denied",
            source_ip=request.get("source_ip", "unknown"),
            deny_reason="role_not_sender",
        )
        raise BrokerError(403, "only sender principals may upload")

    if principal_id != uploader_id:
        write_access_log(
            document_id="n/a",
            session_id=session_id,
            principal_id=principal_id,
            principal_role=principal_role,
            action="upload_presign_request",
            result="denied",
            source_ip=request.get("source_ip", "unknown"),
            deny_reason="uploader_id_mismatch",
        )
        raise BrokerError(403, "cannot upload on behalf of another uploader")

    document = create_document_record(
        session_id=session_id,
        owner_id=request["owner_id"],
        uploader_id=uploader_id,
        receiver_id=request["receiver_id"],
        filename=request["filename"],
    )

    upload_url = generate_upload_url(document["s3_key"], request["content_type"])

    write_access_log(
        document_id=document["document_id"],
        session_id=session_id,
        principal_id=principal_id,
        principal_role=principal_role,
        action="upload_presign_issued",
        result="granted",
        source_ip=request.get("source_ip", "unknown"),
    )

    return {
        "document_id": document["document_id"],
        "upload_url": upload_url,
    }


def download(request: dict) -> dict:
    """
    Issue a presigned GET URL. Only the document's own receiver_id may
    download it — this is the acceptance-criteria-level guarantee: "A
    receiver cannot fetch another receiver's documents."
    """
    principal_id = request["principal_id"]
    principal_role = request["principal_role"]
    document_id = request["document_id"]
    source_ip = request.get("source_ip", "unknown")

    document = get_document(document_id)

    if document is None:
        write_access_log(
            document_id=document_id,
            session_id="unknown",
            principal_id=principal_id,
            principal_role=principal_role,
            action="download_presign_request",
            result="denied",
            source_ip=source_ip,
            deny_reason="document_not_found",
        )
        raise BrokerError(404, "document not found")

    session_id = document["session_id"]

    if principal_role != "receiver" or principal_id != document["receiver_id"]:
        write_access_log(
            document_id=document_id,
            session_id=session_id,
            principal_id=principal_id,
            principal_role=principal_role,
            action="download_presign_request",
            result="denied",
            source_ip=source_ip,
            deny_reason="not_authorized",
        )
        raise BrokerError(403, "not authorized to access this document")

    download_url = generate_download_url(document["s3_key"])

    write_access_log(
        document_id=document_id,
        session_id=session_id,
        principal_id=principal_id,
        principal_role=principal_role,
        action="download_presign_issued",
        result="granted",
        source_ip=source_ip,
    )

    return {"download_url": download_url}


def _normalize_event(event: dict) -> dict:
    """
    Collapse the API Gateway proxy shape and the direct-invoke test shape
    into one internal request dict.
    """
    if "httpMethod" in event:
        claims = event.get("requestContext", {}).get("authorizer", {}).get("claims", {})
        body = json.loads(event.get("body") or "{}")
        path_params = event.get("pathParameters") or {}

        is_download = event["httpMethod"] == "GET"
        action = "download" if is_download else "upload"

        request = {
            "action": action,
            "principal_id": claims.get("sub", ""),
            "principal_role": _role_from_claims(claims),
            "source_ip": event.get("requestContext", {}).get("identity", {}).get("sourceIp", "unknown"),
        }
        request.update(body)
        if "document_id" in path_params:
            request["document_id"] = path_params["document_id"]
        return request

    # Direct invoke — already in internal shape.
    return event


def _role_from_claims(claims: dict) -> str:
    groups = claims.get("cognito:groups", "")
    if isinstance(groups, str):
        groups = groups.split(",") if groups else []
    if "sender" in groups:
        return "sender"
    if "receiver" in groups:
        return "receiver"
    return "unknown"


def _response(status_code: int, body: dict) -> dict:
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }
