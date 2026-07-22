"""
File Secure Exchange — presign broker Lambda.

HTTP API Gateway v2 integration:

POST /documents
    Creates a document registry entry and returns a presigned S3 PUT URL.

GET /documents/{document_id}/download
    Validates receiver ownership and returns a presigned S3 GET URL.

Authentication:
    Cognito JWT authorizer.

Claims location:

    event["requestContext"]["authorizer"]["jwt"]["claims"]

Direct Lambda invocation is also supported for manual testing.
"""

import json
import logging

from audit import write_access_log
from documents import (
    create_document_record,
    generate_download_url,
    generate_upload_url,
    get_document,
)


# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

logger = logging.getLogger()
logger.setLevel(logging.INFO)


# ---------------------------------------------------------------------------
# Application error
# ---------------------------------------------------------------------------

class BrokerError(Exception):

    def __init__(self, status_code: int, message: str):
        super().__init__(message)
        self.status_code = status_code
        self.message = message


# ---------------------------------------------------------------------------
# Lambda entry point
# ---------------------------------------------------------------------------

def handler(event, context):

    logger.info(
        "Received event: %s",
        json.dumps(event, default=str),
    )

    try:

        request = _normalize_event(event)

        logger.info(
            "Normalized request: %s",
            json.dumps(
                {
                    key: value
                    for key, value in request.items()
                    if key not in ["upload_url", "download_url"]
                },
                default=str,
            ),
        )

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

        return _response(
            200,
            result,
        )

    except BrokerError as err:

        logger.warning(
            "Broker error: %s",
            err.message,
        )

        return _response(
            err.status_code,
            {
                "error": err.message,
            },
        )

    except KeyError as err:

        logger.exception(
            "Missing required field",
        )

        return _response(
            400,
            {
                "error": f"missing required field: {err}",
            },
        )

    except Exception:

        logger.exception(
            "Unhandled exception",
        )

        return _response(
            500,
            {
                "error": "internal server error",
            },
        )


# ---------------------------------------------------------------------------
# Upload
# ---------------------------------------------------------------------------

def upload(request: dict) -> dict:

    """
    Create a document record and issue a presigned S3 PUT URL.

    Authorization:

    - principal must be in the sender Cognito group
    - principal_id must equal uploader_id
    """

    principal_id = request["principal_id"]

    principal_role = request["principal_role"]

    session_id = request["session_id"]

    uploader_id = request["uploader_id"]


    # -----------------------------------------------------------------------
    # Role check
    # -----------------------------------------------------------------------

    if principal_role != "sender":

        write_access_log(
            document_id="n/a",
            session_id=session_id,
            principal_id=principal_id,
            principal_role=principal_role,
            action="upload_presign_request",
            result="denied",
            source_ip=request.get(
                "source_ip",
                "unknown",
            ),
            deny_reason="role_not_sender",
        )

        raise BrokerError(
            403,
            "only sender principals may upload",
        )


    # -----------------------------------------------------------------------
    # Sender identity check
    # -----------------------------------------------------------------------

    if principal_id != uploader_id:

        write_access_log(
            document_id="n/a",
            session_id=session_id,
            principal_id=principal_id,
            principal_role=principal_role,
            action="upload_presign_request",
            result="denied",
            source_ip=request.get(
                "source_ip",
                "unknown",
            ),
            deny_reason="uploader_id_mismatch",
        )

        raise BrokerError(
            403,
            "cannot upload on behalf of another uploader",
        )


    # -----------------------------------------------------------------------
    # Create DynamoDB document record
    # -----------------------------------------------------------------------

    document = create_document_record(
        session_id=session_id,
        owner_id=request["owner_id"],
        uploader_id=uploader_id,
        receiver_id=request["receiver_id"],
        filename=request["filename"],
    )


    # -----------------------------------------------------------------------
    # Create presigned S3 upload URL
    # -----------------------------------------------------------------------

    upload_url = generate_upload_url(
        document["s3_key"],
        request["content_type"],
    )


    # -----------------------------------------------------------------------
    # Audit successful presign
    # -----------------------------------------------------------------------

    write_access_log(
        document_id=document["document_id"],
        session_id=session_id,
        principal_id=principal_id,
        principal_role=principal_role,
        action="upload_presign_issued",
        result="granted",
        source_ip=request.get(
            "source_ip",
            "unknown",
        ),
    )


    return {
        "document_id": document["document_id"],
        "upload_url": upload_url,
    }


# ---------------------------------------------------------------------------
# Download
# ---------------------------------------------------------------------------

def download(request: dict) -> dict:

    """
    Issue a presigned S3 GET URL.

    Authorization:

    - principal must be in the receiver Cognito group
    - principal_id must equal the document's receiver_id
    """

    principal_id = request["principal_id"]

    principal_role = request["principal_role"]

    document_id = request["document_id"]

    source_ip = request.get(
        "source_ip",
        "unknown",
    )


    # -----------------------------------------------------------------------
    # Find document
    # -----------------------------------------------------------------------

    document = get_document(
        document_id,
    )


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


    # -----------------------------------------------------------------------
    # Receiver authorization
    # -----------------------------------------------------------------------

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


    # -----------------------------------------------------------------------
    # Generate presigned download URL
    # -----------------------------------------------------------------------

    download_url = generate_download_url(
        document["s3_key"],
    )


    # -----------------------------------------------------------------------
    # Audit successful download presign
    # -----------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# API Gateway HTTP API v2 normalization
# ---------------------------------------------------------------------------

def _normalize_event(event: dict) -> dict:

    """
    Convert an API Gateway HTTP API v2 event into the internal request model.

    Important:

    We use event["routeKey"] instead of relying on the HTTP path.

    API Gateway HTTP API v2 provides routeKey such as:

        POST /documents

    or:

        GET /documents/{document_id}/download
    """

    # -----------------------------------------------------------------------
    # Detect API Gateway HTTP API v2
    # -----------------------------------------------------------------------

    request_context = event.get(
        "requestContext",
        {},
    )


    if "http" in request_context:

        http = request_context["http"]

        route_key = event.get(
            "routeKey",
            "",
        )


        logger.info(
            "API Gateway routeKey: %s",
            route_key,
        )

        logger.info(
            "API Gateway HTTP context: %s",
            json.dumps(
                http,
                default=str,
            ),
        )


        # -------------------------------------------------------------------
        # JWT claims
        # -------------------------------------------------------------------

        claims = (
            request_context
            .get(
                "authorizer",
                {},
            )
            .get(
                "jwt",
                {},
            )
            .get(
                "claims",
                {},
            )
        )


        logger.info(
            "JWT claim keys: %s",
            list(claims.keys()),
        )


        # -------------------------------------------------------------------
        # Parse request body
        # -------------------------------------------------------------------

        body = {}

        if event.get("body"):

            try:

                body = json.loads(
                    event["body"],
                )

            except json.JSONDecodeError:

                raise BrokerError(
                    400,
                    "request body must contain valid JSON",
                )


        # -------------------------------------------------------------------
        # Path parameters
        # -------------------------------------------------------------------

        path_parameters = event.get(
            "pathParameters",
        ) or {}


        # -------------------------------------------------------------------
        # Determine action from matched API Gateway route
        # -------------------------------------------------------------------

        if route_key == "POST /documents":

            action = "upload"


        elif route_key == "GET /documents/{document_id}/download":

            action = "download"


        else:

            raise BrokerError(
                404,
                f"unsupported route: {route_key}",
            )


        # -------------------------------------------------------------------
        # Build internal request
        # -------------------------------------------------------------------

        request = {

            "action": action,

            "principal_id": claims.get(
                "sub",
                "",
            ),

            "principal_role": _role_from_claims(
                claims,
            ),

            "source_ip": http.get(
                "sourceIp",
                "unknown",
            ),

        }


        # Add JSON body fields

        request.update(
            body,
        )


        # Add path parameters

        if "document_id" in path_parameters:

            request["document_id"] = path_parameters[
                "document_id"
            ]


        return request


    # -----------------------------------------------------------------------
    # Direct Lambda invocation
    # -----------------------------------------------------------------------

    logger.info(
        "Treating event as direct invocation",
    )

    return event


# ---------------------------------------------------------------------------
# Cognito role extraction
# ---------------------------------------------------------------------------

def _role_from_claims(claims: dict) -> str:

    """
    Extract sender/receiver role from Cognito groups.
    """

    groups = claims.get(
        "cognito:groups",
        [],
    )


    if isinstance(
        groups,
        str,
    ):

        groups = groups.split(
            ",",
        )


    if "sender" in groups:

        return "sender"


    if "receiver" in groups:

        return "receiver"


    return "unknown"


# ---------------------------------------------------------------------------
# HTTP response
# ---------------------------------------------------------------------------

def _response(
    status_code: int,
    body: dict,
) -> dict:

    return {

        "statusCode": status_code,

        "headers": {
            "Content-Type": "application/json",
        },

        "body": json.dumps(
            body,
        ),

    }