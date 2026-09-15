"""Special events HTTP routes (authuser catalog + service match rules)."""

from __future__ import annotations

from core.errors.app_error import AppError
from core.state.session_scope import session_scope
from core.http.contracts.register_route_contract import ApplicationRouteSink
from core.http.contracts.response_contract import HttpResponseContract
from core.http.request_context import get_auth_user_id, get_current_request
from modules.avari import avari_repository as avari_repo
from modules.special_events.special_events_errors import INVALID_QUERY, NOT_FOUND
from modules.special_events.special_events_loader import event_by_id
from modules.special_events.special_events_service import (
    get_catalog_for_user,
    get_match_rules,
)


def register_special_events_routes(
    routes: ApplicationRouteSink,
    res: HttpResponseContract,
) -> None:
    routes.authuser_get("/special_events/catalog", lambda: _handle_catalog(res))
    routes.service_get(
        "/special_events/match_rules",
        lambda: _handle_match_rules(res),
    )


def _require_user_id() -> str:
    user_id = get_auth_user_id()
    if not user_id:
        raise AppError(INVALID_QUERY, message="Unauthorized")
    return user_id


def _handle_catalog(res: HttpResponseContract):
    try:
        user_id = _require_user_id()
        with session_scope() as session:
            from modules.avari.avari_service import (
                compute_profile_mastery_value_label,
            )

            mastery = 0.0
            titles: list[str] = []
            avari = avari_repo.find_avari_profile(session, user_id)
            if avari is not None:
                raw_titles = getattr(avari, "titles", None) or []
                if isinstance(raw_titles, list):
                    titles = [str(t).strip() for t in raw_titles if str(t).strip()]
                mastery_by = avari_repo.mastery_points_by_design(session, user_id)
                mastery_value, _label = compute_profile_mastery_value_label(
                    mastery_by
                )
                mastery = float(mastery_value)
            return res.json_ok(
                get_catalog_for_user(
                    session,
                    user_id=user_id,
                    mastery_value=mastery,
                    titles=titles,
                )
            )
    except AppError as err:
        return err.to_http_response()


def _handle_match_rules(res: HttpResponseContract):
    try:
        request = get_current_request()
        eid = ""
        if request is not None:
            eid = (
                request.query_params.get("eventId")
                or request.query_params.get("event_id")
                or ""
            ).strip()
        if not eid or event_by_id(eid) is None:
            raise AppError(NOT_FOUND, message="Unknown event")
        return res.json_ok(get_match_rules(eid))
    except AppError as err:
        return err.to_http_response()
