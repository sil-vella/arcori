from core.email.email_verification import resend_email_verification
from core.errors.app_error import AppError
from core.db.db_health import check_database_health
from core.http.contracts.register_route_contract import ApplicationRouteSink
from core.http.contracts.response_contract import HttpResponseContract
from core.http.request_context import get_auth_user_id, get_current_request, parse_upload_file
from core.rate_limit.auth_identity import enforce_auth_identity_rate_limit
from core.utils.dev_logger import customlog
from modules.auth.auth_service import (
    AuthServiceError,
    convert_guest_account,
    delete_account,
    get_user_profile,
    parse_json_body,
)
from modules.user.avatar_service import delete_avatar, upload_avatar

LOGGING_SWITCH = False


def register_user_routes(
    routes: ApplicationRouteSink,
    res: HttpResponseContract,
) -> None:
    routes.public_get(
        "/",
        lambda: res.json_ok({"message": "python_base_05"}),
    )
    routes.public_get(
        "/health",
        lambda: _health_handler(res),
    )
    routes.authuser_get(
        "/user/profile",
        lambda: _profile_handler(res),
    )
    routes.authuser_post(
        "/user/profile/avatar",
        lambda: _upload_avatar_handler(res),
    )
    routes.authuser_delete(
        "/user/profile/avatar",
        lambda: _delete_avatar_handler(res),
    )
    routes.authuser_post(
        "/user/account/delete",
        lambda: _delete_account_handler(res),
    )
    routes.authuser_post(
        "/user/account/convert-guest",
        lambda: _convert_guest_handler(res),
    )
    routes.authuser_post(
        "/user/account/resend-verification",
        lambda: _resend_verification_handler(res),
    )


def _health_handler(res: HttpResponseContract):
    health = check_database_health()
    payload = {
        "status": "up",
        "db": health.db,
        "schema": health.schema,
    }
    if not health.is_ready:
        return res.json_ok(payload, status=503)
    return res.json_ok(payload)


def _profile_handler(res: HttpResponseContract):
    user_id = get_auth_user_id()
    if not user_id:
        return res.json_error(code="unauthorized", message="Unauthorized", status=401)
    profile = get_user_profile(user_id)
    if profile is None:
        return res.json_error(code="not_found", message="User not found", status=404)
    return res.json_ok({"module": "user", "profile": profile})


def _upload_avatar_handler(res: HttpResponseContract):
    user_id = get_auth_user_id()
    if not user_id:
        return res.json_error(code="unauthorized", message="Unauthorized", status=401)
    upload = parse_upload_file("avatar")
    if upload is None or not upload.get("data"):
        request = get_current_request()
        upload_error = getattr(request.state, "upload_error", None) if request else None
        message = "Avatar file is required"
        if upload_error and "python-multipart" in str(upload_error):
            message = "Server cannot parse uploads (python-multipart missing)"
        return res.json_error(
            code="invalid_request",
            message=message,
            status=400,
        )
    if LOGGING_SWITCH:
        customlog(
            f"user_app.upload_avatar: user_id={user_id} "
            f"bytes={len(upload.get('data', b''))}"
        )
    try:
        payload = upload_avatar(user_id=user_id, raw_bytes=upload["data"])
    except AuthServiceError as exc:
        return res.json_error(code=exc.code, message=exc.message, status=exc.status)
    return res.json_ok(payload)


def _delete_avatar_handler(res: HttpResponseContract):
    user_id = get_auth_user_id()
    if not user_id:
        return res.json_error(code="unauthorized", message="Unauthorized", status=401)
    try:
        payload = delete_avatar(user_id=user_id)
    except AuthServiceError as exc:
        return res.json_error(code=exc.code, message=exc.message, status=exc.status)
    return res.json_ok(payload)


def _delete_account_handler(res: HttpResponseContract):
    user_id = get_auth_user_id()
    if not user_id:
        return res.json_error(code="unauthorized", message="Unauthorized", status=401)
    body = parse_json_body()
    try:
        delete_account(
            user_id=user_id,
            password=str(body.get("password", "")),
            confirmation=str(body.get("confirmation", "")),
        )
    except AuthServiceError as exc:
        return res.json_error(code=exc.code, message=exc.message, status=exc.status)
    return res.json_ok({"deleted": True})


def _convert_guest_handler(res: HttpResponseContract):
    user_id = get_auth_user_id()
    if not user_id:
        return res.json_error(code="unauthorized", message="Unauthorized", status=401)
    body = parse_json_body()
    if LOGGING_SWITCH:
        customlog(
            f"user_app.convert_guest: user_id={user_id} "
            f"guest_email={body.get('guest_email', '')} "
            f"new_email={body.get('email', '')} username={body.get('username', '')}"
        )
    try:
        payload = convert_guest_account(
            user_id=user_id,
            guest_email=str(body.get("guest_email", "")),
            username=str(body.get("username", "")),
            email=str(body.get("email", "")),
            password=str(body.get("password", "")),
        )
    except AuthServiceError as exc:
        if LOGGING_SWITCH:
            customlog(
                f"user_app.convert_guest: failed user_id={user_id} "
                f"code={exc.code} status={exc.status}"
            )
        return res.json_error(code=exc.code, message=exc.message, status=exc.status)
    except AppError as err:
        return err.to_http_response()
    if LOGGING_SWITCH:
        customlog(f"user_app.convert_guest: ok user_id={user_id}")
    return res.json_ok(payload)


def _resend_verification_handler(res: HttpResponseContract):
    user_id = get_auth_user_id()
    if not user_id:
        return res.json_error(code="unauthorized", message="Unauthorized", status=401)
    profile = get_user_profile(user_id)
    if profile is None:
        return res.json_error(code="not_found", message="User not found", status=404)
    try:
        enforce_auth_identity_rate_limit(str(profile.get("email") or user_id))
        resend_email_verification(user_id)
    except AppError as err:
        return err.to_http_response()
    return res.json_ok({"resent": True})
