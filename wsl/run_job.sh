#!/usr/bin/env bash
# Run the Spark analysis (reads HDFS, writes results to HDFS and Cassandra).
set -euo pipefail
source "$(dirname "$0")/env.sh"
spark-submit --master 'local[*]' --driver-memory 1500m "$PROJECT_DIR/app/job.py"
