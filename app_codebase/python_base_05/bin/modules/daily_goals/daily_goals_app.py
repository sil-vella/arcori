"""Daily goals HTTP routes (authuser catalog + progress + continue/claim)."""

from __future__ import annotations

import uuid

from core.errors.app_error import AppError
from core.http.contracts.register_route_contract import ApplicationRouteSink
from core.http.contracts.response_contract import HttpResponseContract
from core.http.request_context import get_auth_user_id
from core.state.session_scope import session_scope
from modules.auth.auth_service import get_user_profile, parse_json_body
from modules.avari import avari_repository as avari_repo
from modules.daily_goals.daily_goals_errors import INVALID_QUERY
from modules.daily_goals.daily_goals_service import (
    accept_reset,
    claim_goal,
    continue_goal,
    get_catalog_payload,
    get_progress_payload,
    parse_goal_id_body,
)


def register_daily_goals_routes(
    routes: ApplicationRouteSink,
    res: HttpResponseContract,
) -> None:
    routes.authuser_get("/daily_goals/catalog", lambda: _handle_catalog(res))
    routes.authuser_get("/daily_goals/progress", lambda: _handle_progress(res))
    routes.authuser_post("/daily_goals/continue", lambda: _handle_continue(res))
    routes.authuser_post(
        "/daily_goals/accept_reset", lambda: _handle_accept_reset(res)
    )
    routes.authuser_post("/daily_goals/claim", lambda: _handle_claim(res))


def _require_user_id() -> str:
    user_id = get_auth_user_id()
    if not user_id:
        raise AppError(INVALID_QUERY, message="Unauthorized")
    return user_id


def _ensure_avari(session, user_id: str):
    profile = get_user_profile(user_id)
    display_name = (
        str((profile or {}).get("username") or "").strip() or "Avari"
    )
    return avari_repo.ensure_avari_profile(
        session,
        user_id=uuid.UUID(user_id),
        display_name=display_name,
    )


def _handle_catalog(res: HttpResponseContract):
    try:
        _require_user_id()
        return res.json_ok(get_catalog_payload())
    except AppError as err:
        return err.to_http_response()


def _handle_progress(res: HttpResponseContract):
    try:
        user_id = _require_user_id()
        with session_scope() as session:
            avari = _ensure_avari(session, user_id)
            return res.json_ok(
                get_progress_payload(session, user_id=user_id, avari=avari)
            )
    except AppError as err:
        return err.to_http_response()


def _handle_continue(res: HttpResponseContract):
    try:
        user_id = _require_user_id()
        body = parse_json_body()
        goal_id = parse_goal_id_body(body)
        with session_scope() as session:
            avari = _ensure_avari(session, user_id)
            return res.json_ok(
                continue_goal(
                    session, user_id=user_id, avari=avari, goal_id=goal_id
                )
            )
    except AppError as err:
        return err.to_http_response()


def _handle_accept_reset(res: HttpResponseContract):
    try:
        user_id = _require_user_id()
        body = parse_json_body()
        goal_id = parse_goal_id_body(body)
        with session_scope() as session:
            avari = _ensure_avari(session, user_id)
            return res.json_ok(
                accept_reset(
                    session, user_id=user_id, avari=avari, goal_id=goal_id
                )
            )
    except AppError as err:
        return err.to_http_response()


def _handle_claim(res: HttpResponseContract):
    try:
        user_id = _require_user_id()
        body = parse_json_body()
        goal_id = parse_goal_id_body(body)
        with session_scope() as session:
            avari = _ensure_avari(session, user_id)
            return res.json_ok(
                claim_goal(
                    session, user_id=user_id, avari=avari, goal_id=goal_id
                )
            )
    except AppError as err:
        return err.to_http_response()
