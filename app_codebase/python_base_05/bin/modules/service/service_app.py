from core.http.contracts.register_route_contract import ApplicationRouteSink
from core.http.contracts.response_contract import HttpResponseContract


def register_service_routes(
    routes: ApplicationRouteSink,
    res: HttpResponseContract,
) -> None:
    routes.service_get(
        "/health",
        lambda: res.json_ok({"module": "service", "status": "up"}),
    )
