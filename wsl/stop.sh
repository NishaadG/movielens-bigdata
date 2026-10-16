#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
pkill -f "uvicorn api:app" 2>/dev/null || true
hdfs --daemon stop datanode || true
hdfs --daemon stop namenode || true
if [ -f "$BD/cassandra.pid" ]; then kill "$(cat "$BD/cassandra.pid")" 2>/dev/null || true; rm -f "$BD/cassandra.pid"; fi
echo "stopped"
