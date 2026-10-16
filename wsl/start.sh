#!/usr/bin/env bash
# Start HDFS (NameNode + DataNode) and Cassandra.
set -euo pipefail
source "$(dirname "$0")/env.sh"

hdfs --daemon start namenode
hdfs --daemon start datanode
hdfs dfsadmin -safemode wait >/dev/null
echo "HDFS is up   -> http://localhost:9870"

if [ -f "$BD/cassandra.pid" ] && kill -0 "$(cat "$BD/cassandra.pid")" 2>/dev/null; then
  echo "Cassandra already running"
else
  cassandra -p "$BD/cassandra.pid" > "$BD/logs/cassandra.out" 2>&1
fi
echo -n "waiting for Cassandra"
until cqlsh -e 'DESCRIBE KEYSPACES' >/dev/null 2>&1; do echo -n "."; sleep 5; done
echo
echo "Cassandra is up (port 9042)"
jps | grep -E "NameNode|DataNode|CassandraDaemon" || true
