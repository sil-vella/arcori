"""Players HTTP routes (service AI sample for Dart matchmaking)."""

from __future__ import annotations

from core.errors.app_error import AppError
from core.http.contracts.register_route_contract import ApplicationRouteSink
from core.http.contracts.response_contract import HttpResponseContract
from modules.auth.auth_service import parse_json_body
from modules.players.players_errors import INVALID_REQUEST
from modules.players.players_service import sample_ai_players


def register_players_routes(
    routes: ApplicationRouteSink,
    res: HttpResponseContract,
) -> None:
    routes.service_post("/players/ai/sample", lambda: _handle_ai_sample(res))


def _handle_ai_sample(res: HttpResponseContract):
    try:
        body = parse_json_body()
        count_raw = body.get("count", 1)
        try:
            count = int(count_raw)
        except (TypeError, ValueError) as exc:
            raise AppError(INVALID_REQUEST, message="count must be an int") from exc
        exclude = body.get("excludeUserIds") or body.get("exclude_user_ids") or []
        if not isinstance(exclude, list):
            exclude = []
        return res.json_ok(
            sample_ai_players(
                count=count,
                exclude_user_ids=[str(x) for x in exclude],
            )
        )
    except AppError as err:
        return err.to_http_response()
