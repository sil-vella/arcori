#!/usr/bin/env bash
# dash Enter/exit/status/poll app-layer drain via ops_drain.py
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OPS_DRAIN_BASE_URL="${OPS_DRAIN_BASE_URL:-http://127.0.0.1:8000}"
export OPS_DRAIN_BASE_URL

exec python3 "${ROOT}/app_codebase/python_base_05/tools/ops_drain.py" "$@"
