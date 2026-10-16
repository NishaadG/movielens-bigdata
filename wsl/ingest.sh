#!/usr/bin/env bash
# Copy the CSV files into HDFS and create the Cassandra tables.
set -euo pipefail
source "$(dirname "$0")/env.sh"
hdfs dfs -mkdir -p /movielens
hdfs dfs -put -f "$PROJECT_DIR/data/ratings.csv" "$PROJECT_DIR/data/movies.csv" /movielens/
hdfs dfs -ls /movielens
cqlsh -f "$PROJECT_DIR/cassandra/schema.cql"
echo "ingest done"
