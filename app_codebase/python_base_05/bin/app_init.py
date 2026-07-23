"""Build the HTTP app and run the development server (mirrors Dart ``app_init.dart``)."""

import os
import sys

# Treat this directory as the import root (same role as Dart ``bin/``).
_bin_root = os.path.dirname(os.path.abspath(__file__))
if _bin_root not in sys.path:
    sys.path.insert(0, _bin_root)

from core.auth.auth_config import require_app_debug_safe
from core.http.http_app import createHttpHandler


def start_app() -> None:
    """Create the FastAPI app and bind to ``PORT`` (default 8000)."""
    require_app_debug_safe()
    app = createHttpHandler()
    port = int(os.environ.get("PORT", "8000"))
    import uvicorn

    from core.auth.auth_config import app_debug_enabled

    uvicorn.run(
        app,
        host="0.0.0.0",
        port=port,
        reload=app_debug_enabled(),
    )
