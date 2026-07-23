"""Core (framework-owned) error codes — modules must not register these."""

from core.errors.error_spec import ErrorSpec

UNAUTHORIZED = ErrorSpec("unauthorized", "Bearer token required", 401, fatal_ws=True)
TOKEN_EXPIRED = ErrorSpec("token_expired", "Access token expired", 401, fatal_ws=True)
INVALID_TOKEN = ErrorSpec("invalid_token", "Invalid access token", 401, fatal_ws=True)
FORBIDDEN = ErrorSpec("forbidden", "Forbidden", 403, fatal_ws=True)
NOT_FOUND = ErrorSpec("not_found", "Not found", 404)
INVALID_JSON = ErrorSpec("invalid_json", "Message must be valid JSON", 400)
INVALID_MESSAGE = ErrorSpec("invalid_message", "Invalid message", 400)
NOT_IMPLEMENTED = ErrorSpec("not_implemented", "Not implemented", 501)
RATE_LIMITED = ErrorSpec("rate_limited", "Too many requests", 429)
INTERNAL_ERROR = ErrorSpec("internal_error", "Internal server error", 500)

CORE_ERROR_SPECS: tuple[ErrorSpec, ...] = (
    UNAUTHORIZED,
    TOKEN_EXPIRED,
    INVALID_TOKEN,
    FORBIDDEN,
    NOT_FOUND,
    INVALID_JSON,
    INVALID_MESSAGE,
    NOT_IMPLEMENTED,
    RATE_LIMITED,
    INTERNAL_ERROR,
)

CORE_CODES: frozenset[str] = frozenset(spec.code for spec in CORE_ERROR_SPECS)
