# Shared settings, sourced by the other scripts. Everything is installed under ~/bigdata (inside WSL).
export BD="$HOME/bigdata"
export PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export HADOOP_HOME="$BD/hadoop-3.3.6"
export HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"
export HADOOP_LOG_DIR="$BD/logs"
export SPARK_HOME="$BD/spark-3.5.3-bin-hadoop3"
export CASSANDRA_HOME="$BD/apache-cassandra-4.1.7"
# venv first: Cassandra's bundled cqlsh does not run on Python 3.12, the pip "cqlsh" does
export PATH="$BD/venv/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$SPARK_HOME/bin:$CASSANDRA_HOME/bin:$PATH"

# used by app/job.py and app/api.py
export HDFS_URL=hdfs://localhost:9000
export HDFS_WEB=http://localhost:9870
export CASSANDRA_HOST=127.0.0.1
export REPLICATION=1
export MIN_RATINGS="${MIN_RATINGS:-1000}"
export PYSPARK_PYTHON="$BD/venv/bin/python"

# keep Cassandra small enough for a laptop
export MAX_HEAP_SIZE=512M
export HEAP_NEWSIZE=128M
