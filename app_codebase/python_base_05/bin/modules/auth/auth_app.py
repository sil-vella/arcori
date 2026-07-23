"""Auth routes: dev-login (local), register, login, refresh, service validate.

Do not cache these endpoints. Google Sign-In exchange will be added later.
"""

from core.email.email_verification import verify_email_token
from core.errors.app_error import AppError
from core.http.contracts.register_route_contract import ApplicationRouteSink
from core.http.contracts.response_contract import HttpResponseContract
from core.utils.dev_logger import customlog
from modules.auth.auth_service import (
    AuthServiceError,
    dev_login,
    login,
    logout_refresh_token,
    parse_json_body,
    refresh_access_token,
    register,
    validate_access_token,
)


LOGGING_SWITCH = True


def register_auth_routes(
    routes: ApplicationRouteSink,
    res: HttpResponseContract,
) -> None:
    routes.public_post(
        "/public/auth/dev-login",
        lambda: _handle_dev_login(res),
    )
    routes.public_post(
        "/public/auth/register",
        lambda: _handle_register(res),
    )
    routes.public_post(
        "/public/auth/login",
        lambda: _handle_login(res),
    )
    routes.public_post(
        "/public/auth/refresh",
        lambda: _handle_refresh(res),
    )
    routes.public_post(
        "/public/auth/logout",
        lambda: _handle_logout(res),
    )
    routes.public_post(
        "/public/auth/verify-email",
        lambda: _handle_verify_email(res),
    )
    routes.service_post(
        "/auth/validate",
        lambda: _handle_validate(res),
    )


def _handle_dev_login(res: HttpResponseContract):
    body = parse_json_body()
    user_id = str(body.get("user_id", ""))
    payload = dev_login(user_id)
    if payload is None:
        return res.json_error(
            code="forbidden",
            message="Dev login is not available",
            status=403,
        )
    return res.json_ok(payload)


def _handle_register(res: HttpResponseContract):
    body = parse_json_body()
    is_guest = bool(body.get("is_guest", False))
    if LOGGING_SWITCH and is_guest:
        customlog(
            "auth_app.register: guest request "
            f"username={body.get('username', '')} email={body.get('email', '')}"
        )
    try:
        payload = register(
            username=str(body.get("username", "")),
            email=str(body.get("email", "")),
            password=str(body.get("password", "")),
            is_guest=is_guest,
        )
    except AppError as err:
        return err.to_http_response()
    except AuthServiceError as exc:
        if LOGGING_SWITCH and is_guest:
            customlog(
                f"auth_app.register: guest failed code={exc.code} message={exc.message}"
            )
        return res.json_error(code=exc.code, message=exc.message, status=exc.status)
    if LOGGING_SWITCH and is_guest:
        customlog(
            f"auth_app.register: guest ok user_id={payload.get('user_id', '')}"
        )
    return res.json_ok(payload)


def _handle_login(res: HttpResponseContract):
    body = parse_json_body()
    email = str(body.get("email", "")).strip().lower()
    is_guest_email = email.endswith("@arcori.arcori")
    if LOGGING_SWITCH and is_guest_email:
        customlog(f"auth_app.login: guest request email={email}")
    try:
        payload = login(
            email=str(body.get("email", "")),
            password=str(body.get("password", "")),
        )
    except AppError as err:
        return err.to_http_response()
    except AuthServiceError as exc:
        if LOGGING_SWITCH and is_guest_email:
            customlog(
                f"auth_app.login: guest failed code={exc.code} message={exc.message}"
            )
        return res.json_error(code=exc.code, message=exc.message, status=exc.status)
    if LOGGING_SWITCH and is_guest_email:
        customlog(f"auth_app.login: guest ok user_id={payload.get('user_id', '')}")
    return res.json_ok(payload)


def _handle_refresh(res: HttpResponseContract):
    body = parse_json_body()
    refresh_token = str(body.get("refresh_token", ""))
    payload = refresh_access_token(refresh_token)
    if payload is None:
        return res.json_error(
            code="invalid_token",
            message="Invalid or expired refresh token",
            status=401,
        )
    return res.json_ok(payload)


def _handle_logout(res: HttpResponseContract):
    body = parse_json_body()
    refresh_token = str(body.get("refresh_token", ""))
    logout_refresh_token(refresh_token)
    return res.json_ok({"logged_out": True})


def _handle_verify_email(res: HttpResponseContract):
    body = parse_json_body()
    token = str(body.get("token", ""))
    try:
        payload = verify_email_token(token)
    except AppError as err:
        return err.to_http_response()
    return res.json_ok(payload)


def _handle_validate(res: HttpResponseContract):
    body = parse_json_body()
    access_token = str(body.get("access_token", ""))
    payload = validate_access_token(access_token)
    if payload is None:
        return res.json_error(
            code="invalid_token",
            message="Invalid or expired access token",
            status=401,
        )
    return res.json_ok(payload)
