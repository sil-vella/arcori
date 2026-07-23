"""ASGI entrypoint for Gunicorn (UvicornWorker) and uvicorn."""

import os
import sys

_bin_root = os.path.dirname(os.path.abspath(__file__))
if _bin_root not in sys.path:
    sys.path.insert(0, _bin_root)

from core.http.http_app import createHttpHandler

app = createHttpHandler()
