#!/usr/bin/env bash
# One-time install: Hadoop 3.3.6 (single node), Spark 3.5.3, Cassandra 4.1.7 and a Python venv.
set -euo pipefail
source "$(dirname "$0")/env.sh"
mkdir -p "$BD/downloads" "$BD/hdfs/name" "$BD/hdfs/data" "$BD/logs"

fetch() {  # fetch <url> <folder it unpacks to>
  local url=$1 dir=$2 file="$BD/downloads/$(basename "$1")"
  if [ -d "$BD/$dir" ]; then echo "$dir already installed"; return; fi
  echo "downloading $(basename "$url") ..."
  curl -fL --retry 5 --retry-delay 3 -C - -o "$file" "$url"
  tar -xzf "$file" -C "$BD"
}
fetch https://archive.apache.org/dist/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz hadoop-3.3.6
fetch https://archive.apache.org/dist/spark/spark-3.5.3/spark-3.5.3-bin-hadoop3.tgz spark-3.5.3-bin-hadoop3
fetch https://archive.apache.org/dist/cassandra/4.1.7/apache-cassandra-4.1.7-bin.tar.gz apache-cassandra-4.1.7

# ---- Hadoop: pseudo-distributed (one NameNode + one DataNode on this machine)
cat > "$HADOOP_CONF_DIR/core-site.xml" <<XML
<?xml version="1.0"?>
<configuration>
  <property><name>fs.defaultFS</name><value>hdfs://localhost:9000</value></property>
</configuration>
XML
cat > "$HADOOP_CONF_DIR/hdfs-site.xml" <<XML
<?xml version="1.0"?>
<configuration>
  <property><name>dfs.replication</name><value>1</value></property>
  <property><name>dfs.namenode.name.dir</name><value>file://$BD/hdfs/name</value></property>
  <property><name>dfs.datanode.data.dir</name><value>file://$BD/hdfs/data</value></property>
  <property><name>dfs.webhdfs.enabled</name><value>true</value></property>
</configuration>
XML
if ! grep -q "movielens-bigdata settings" "$HADOOP_CONF_DIR/hadoop-env.sh"; then
  {
    echo "# movielens-bigdata settings"
    echo "export JAVA_HOME=$JAVA_HOME"
    echo "export HADOOP_HEAPSIZE_MAX=512m"
  } >> "$HADOOP_CONF_DIR/hadoop-env.sh"
fi

if [ ! -d "$BD/hdfs/name/current" ]; then
  hdfs namenode -format -force -nonInteractive
fi

# ---- Python venv (python3-venv/ensurepip is not installed, so bootstrap pip ourselves)
if [ ! -x "$BD/venv/bin/pip" ]; then
  python3 -m venv --without-pip "$BD/venv"
  curl -fsSL https://bootstrap.pypa.io/get-pip.py -o "$BD/downloads/get-pip.py"
  "$BD/venv/bin/python" "$BD/downloads/get-pip.py" -q
fi
"$BD/venv/bin/pip" install -q -r "$PROJECT_DIR/wsl/requirements.txt"

echo
echo "Setup finished. Next: ./wsl/start.sh"
