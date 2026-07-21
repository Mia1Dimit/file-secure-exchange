"""
File Secure Exchange — presign broker Lambda.

Entry point: handler(event, context).

Supports:

1. API Gateway HTTP API v2 Lambda proxy integration
   - POST /documents
     Creates document registry entry and returns presigned S3 PUT URL.

   - GET /documents/{document_id}/download
     Validates receiver ownership and returns presigned S3 GET URL.

   Authentication:
   - Cognito JWT authorizer
   - Claims location:
       event["requestContext"]["authorizer"]["jwt"]["claims"]

2. Direct Lambda invocation for local/manual testing:

{
    "action": "upload" | "download",
    "principal_id": "...",
    "principal_role": "sender" | "receiver",
    "source_ip": "test",
    ...
}

Both paths converge into the same upload()/download() authorization logic.
"""

import json

from audit import write_access_log
from documents import (
    create_document_record,
    generate_download_url,
    generate_upload_url,
    get_document,
)


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
            raise BrokerError(
                400,
                f"unknown action: {action}",
            )

        return _response(200, result)

    except BrokerError as err:
        return _response(
            err.status_code,
            {"error": err.message},
        )

    except KeyError as err:
        return _response(
            400,
            {"error": f"missing required field: {err}"},
        )

    except Exception as err:
        return _response(
            500,
            {"error": "internal server error"},
        )


def upload(request: dict) -> dict:
    """
    Create a document record and issue a presigned PUT URL.

    Only sender principals may upload.
    A sender can only upload for themselves.
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

        raise BrokerError(
            403,
            "only sender principals may upload",
        )

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

        raise BrokerError(
            403,
            "cannot upload on behalf of another uploader",
        )

    document = create_document_record(
        session_id=session_id,
        owner_id=request["owner_id"],
        uploader_id=uploader_id,
        receiver_id=request["receiver_id"],
        filename=request["filename"],
    )

    upload_url = generate_upload_url(
        document["s3_key"],
        request["content_type"],
    )

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
    Issue a presigned GET URL.

    Only the receiver assigned to the document may download it.
    """

    principal_id = request["principal_id"]
    principal_role = request["principal_role"]
    document_id = request["document_id"]

    source_ip = request.get(
        "source_ip",
        "unknown",
    )

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

        raise BrokerError(
            404,
            "document not found",
        )

    session_id = document["session_id"]

    if (
        principal_role != "receiver"
        or principal_id != document["receiver_id"]
    ):

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

        raise BrokerError(
            403,
            "not authorized to access this document",
        )

    download_url = generate_download_url(
        document["s3_key"]
    )

    write_access_log(
        document_id=document_id,
        session_id=session_id,
        principal_id=principal_id,
        principal_role=principal_role,
        action="download_presign_issued",
        result="granted",
        source_ip=source_ip,
    )

    return {
        "download_url": download_url,
    }


def _normalize_event(event: dict) -> dict:
    """
    Convert API Gateway HTTP API v2 payloads into the internal request model.
    """

    # API Gateway HTTP API v2
    if (
        "requestContext" in event
        and "http" in event["requestContext"]
    ):

        request_context = event["requestContext"]

        http = request_context["http"]

        method = http["method"]
        path = http["path"]

        claims = (
            request_context
            .get("authorizer", {})
            .get("jwt", {})
            .get("claims", {})
        )

        body = {}

        if event.get("body"):
            body = json.loads(event["body"])

        path_parameters = event.get(
            "pathParameters"
        ) or {}

        if method == "POST" and path == "/documents":

            action = "upload"

        elif (
            method == "GET"
            and "document_id" in path_parameters
        ):

            action = "download"

        else:

            raise BrokerError(
                400,
                f"unsupported route: {method} {path}",
            )

        request = {
            "action": action,

            "principal_id": claims.get(
                "sub",
                "",
            ),

            "principal_role": _role_from_claims(
                claims
            ),

            "source_ip": http.get(
                "sourceIp",
                "unknown",
            ),
        }

        request.update(body)

        if "document_id" in path_parameters:
            request["document_id"] = path_parameters[
                "document_id"
            ]

        return request

    # Direct invocation testing
    return event


def _role_from_claims(claims: dict) -> str:
    """
    Extract application role from Cognito groups.
    """

    groups = claims.get(
        "cognito:groups",
        [],
    )

    if isinstance(groups, str):
        groups = groups.split(",")

    if "sender" in groups:
        return "sender"

    if "receiver" in groups:
        return "receiver"

    return "unknown"


def _response(status_code: int, body: dict) -> dict:
    """
    HTTP API Lambda proxy response.
    """

    return {
        "statusCode": status_code,
        "headers": {
            "content-type": "application/json",
        },
        "body": json.dumps(body),
    }