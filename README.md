# MovieLens ratings analytics (Big Data mini-project)

A small big-data pipeline that analyses the MovieLens ratings dataset and shows the results on a web dashboard.

```
CSV files -> HDFS (storage) -> Spark (analysis) -> Cassandra (results) -> web dashboard
```

| Tool | Version | Role |
|---|---|---|
| Hadoop HDFS | 3.3.6 | stores the raw CSV files and the Spark output |
| Apache Spark | 3.5.3 | reads from HDFS, computes the statistics |
| Apache Cassandra | 4.1.7 | stores the final results |
| FastAPI + plain HTML/CSS/JS | | dashboard that reads Cassandra |

## Run it on WSL (Ubuntu)

Needs WSL2 with Ubuntu, Java 11 (`sudo apt install openjdk-11-jre-headless`) and about 3 GB of free RAM.
Everything is installed under `~/bigdata`, nothing is installed system-wide.

```bash
# from the project folder, inside WSL
./wsl/setup.sh        # once: downloads Hadoop, Spark, Cassandra (~1.2 GB) and sets up Python
# get the dataset (from Windows PowerShell:  .\scripts\download_data.ps1)  ->  data/ratings.csv, data/movies.csv

./wsl/start.sh        # starts HDFS and Cassandra
./wsl/ingest.sh       # copies the CSVs into HDFS, creates the Cassandra tables
./wsl/run_job.sh      # runs the Spark job
./wsl/run_web.sh      # dashboard at http://localhost:8088   (HDFS web UI: http://localhost:9870)

./wsl/stop.sh         # shut everything down
```

The dataset download script (`scripts/download_data.ps1`) is for PowerShell. Inside WSL you can do the same with:

```bash
curl -L https://files.grouplens.org/datasets/movielens/ml-latest-small.zip -o /tmp/ml.zip
unzip /tmp/ml.zip -d /tmp && cp /tmp/ml-latest-small/{ratings,movies}.csv data/
```

## Commands worth showing in a demo

```bash
source wsl/env.sh
hdfs dfs -ls /movielens                              # files in HDFS
hdfs fsck /movielens -files -blocks                  # blocks and replication factor
hdfs dfs -get /movielens/ratings.csv /tmp/copy.csv   # download a file back
hdfs dfs -ls /movielens/output                       # Spark results saved in HDFS
cqlsh -e "SELECT * FROM movielens.top_by_genre WHERE genre='Comedy';"
```

## What the Spark job computes (`app/job.py`)

- Row count, number of users and movies, average rating, number of ratings of 4 stars or more.
- Average rating per genre.
- Top 10 movies overall and per genre (movies with fewer than 50 ratings are ignored).
- Movies per genre with a map / reduceByKey on an RDD (the MapReduce idea).

Results go back to HDFS (`/movielens/output`) as CSV and into Cassandra (`cassandra/schema.cql`).

## Project layout

| Path | What it is |
|---|---|
| `wsl/` | install and run scripts for WSL |
| `app/job.py` | PySpark job |
| `app/api.py`, `app/static/` | API and dashboard |
| `cassandra/schema.cql` | Cassandra tables |

Dataset: MovieLens, GroupLens Research, University of Minnesota.
