#!/usr/bin/env bash
# Start the dashboard on http://localhost:8088
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$PROJECT_DIR/app"
exec uvicorn api:app --host 0.0.0.0 --port "${WEB_PORT:-8088}"
