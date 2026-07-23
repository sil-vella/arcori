"""Gunicorn configuration for Arcori FastAPI (python_base_05).

Override via environment: GUNICORN_WORKERS, GUNICORN_TIMEOUT, PORT.
"""

from __future__ import annotations

import multiprocessing
import os

bind = f"0.0.0.0:{os.environ.get('PORT', '8000')}"

workers = int(os.environ.get("GUNICORN_WORKERS", "2"))
worker_class = os.environ.get("GUNICORN_WORKER_CLASS", "uvicorn.workers.UvicornWorker")
timeout = int(os.environ.get("GUNICORN_TIMEOUT", "60"))

max_requests = int(os.environ.get("GUNICORN_MAX_REQUESTS", "1000"))
max_requests_jitter = int(os.environ.get("GUNICORN_MAX_REQUESTS_JITTER", "100"))

preload_app = False

accesslog = "-"
errorlog = "-"
loglevel = os.environ.get("GUNICORN_LOG_LEVEL", "info")

# %(D)s = request duration in microseconds
access_log_format = (
    '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" duration_us=%(D)s'
)

# Sensible default when env omits worker count on tiny hosts
if workers < 1:
    workers = max(2, multiprocessing.cpu_count())
