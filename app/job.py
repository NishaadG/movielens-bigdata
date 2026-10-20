"""
Spark batch job: HDFS -> analysis -> HDFS (csv) + Cassandra.

Reads ratings.csv and movies.csv from HDFS, computes the numbers shown on the
dashboard, writes them back to HDFS as CSV and loads them into Cassandra.
"""
import os
import time
from operator import add

from cassandra.cluster import Cluster
from pyspark.sql import SparkSession, Window
from pyspark.sql import functions as F

HDFS = os.environ.get("HDFS_URL", "hdfs://localhost:9000")
CASSANDRA_HOST = os.environ.get("CASSANDRA_HOST", "127.0.0.1")
MIN_RATINGS = int(os.environ.get("MIN_RATINGS", "50"))  # ignore movies with too few votes
TOP_N = 10

IN_DIR = f"{HDFS}/movielens"
OUT_DIR = f"{HDFS}/movielens/output"

spark = (
    SparkSession.builder.appName("movielens-analytics")
    .master("local[*]")
    .config("spark.driver.memory", "1g")
    .config("spark.hadoop.dfs.replication", os.environ.get("REPLICATION", "1"))
    .config("spark.sql.shuffle.partitions", "8")
    .config("spark.ui.showConsoleProgress", "false")
    .getOrCreate()
)
spark.sparkContext.setLogLevel("ERROR")

# ---------------------------------------------------------------- 1. load from HDFS
ratings = spark.read.csv(f"{IN_DIR}/ratings.csv", header=True, inferSchema=True)
movies = spark.read.csv(f"{IN_DIR}/movies.csv", header=True, inferSchema=True)
ratings.cache()

# ---------------------------------------------------------------- 2. basic numbers
total_ratings = ratings.count()
total_users = ratings.select("userId").distinct().count()
total_movies = movies.count()
avg_rating = ratings.agg(F.avg("rating")).first()[0]
high_ratings = ratings.filter(F.col("rating") >= 4).count()  # numeric filter

summary = {
    "total_ratings": float(total_ratings),
    "total_users": float(total_users),
    "total_movies": float(total_movies),
    "avg_rating": float(avg_rating),
    "high_ratings": float(high_ratings),
}
print("SUMMARY", summary)

# ---------------------------------------------------------------- 3. per-movie stats
movie_stats = (
    ratings.groupBy("movieId")
    .agg(F.avg("rating").alias("avg_rating"), F.count("*").alias("num_ratings"))
    .join(movies, "movieId")
)
popular = movie_stats.filter(F.col("num_ratings") >= MIN_RATINGS)

# ---------------------------------------------------------------- 4. per-genre stats
# one movie row per genre: "Action|Comedy" -> two rows
movie_genres = movies.select(
    "movieId", "title", F.explode(F.split("genres", r"\|")).alias("genre")
).filter(F.col("genre") != "(no genres listed)")

genre_stats = (
    ratings.join(movie_genres, "movieId")
    .groupBy("genre")
    .agg(
        F.count("*").alias("num_ratings"),
        F.avg("rating").alias("avg_rating"),
    )
    .orderBy(F.desc("avg_rating"))
)

# ---------------------------------------------------------------- 5. top movies per genre
w = Window.partitionBy("genre").orderBy(F.desc("avg_rating"), F.desc("num_ratings"))
top_per_genre = (
    popular.select("movieId", "avg_rating", "num_ratings")
    .join(movie_genres, "movieId")
    .withColumn("rank", F.row_number().over(w))
    .filter(F.col("rank") <= TOP_N)
    .select("genre", "rank", "title", "avg_rating", "num_ratings")
)
w_all = Window.orderBy(F.desc("avg_rating"), F.desc("num_ratings"))
top_overall = (
    popular.withColumn("rank", F.row_number().over(w_all))
    .filter(F.col("rank") <= TOP_N)
    .select(F.lit("All").alias("genre"), "rank", "title", "avg_rating", "num_ratings")
)
top_movies = top_overall.unionByName(top_per_genre)

# ---------------------------------------------------------------- 6. MapReduce-style genre count (RDD)
# map: movie -> (genre, 1)   reduce: sum per genre
genre_counts = (
    movies.rdd.flatMap(lambda r: r["genres"].split("|"))
    .map(lambda g: (g, 1))
    .reduceByKey(add)
    .sortBy(lambda kv: -kv[1])
)
print("GENRE COUNTS (movies per genre)", genre_counts.take(5))

# ---------------------------------------------------------------- 7. write results back to HDFS
for name, df in [
    ("genre_stats", genre_stats),
    ("top_movies", top_movies),
]:
    df.coalesce(1).write.mode("overwrite").option("header", True).csv(f"{OUT_DIR}/{name}")
spark.createDataFrame(genre_counts.collect(), ["genre", "movies"]).coalesce(1).write.mode(
    "overwrite"
).option("header", True).csv(f"{OUT_DIR}/genre_counts")

# ---------------------------------------------------------------- 8. load into Cassandra
# results are tiny (a few hundred rows) so collecting them to the driver is fine
def connect():
    for attempt in range(30):
        try:
            return Cluster([CASSANDRA_HOST]).connect("movielens")
        except Exception as e:  # cassandra still starting / schema not applied
            print(f"waiting for cassandra ({attempt + 1}/30): {e}")
            time.sleep(5)
    raise SystemExit("could not reach cassandra")


session = connect()

for t in ["summary", "genre_stats", "top_by_genre"]:
    session.execute(f"TRUNCATE {t}")

ins = session.prepare("INSERT INTO summary (metric, value) VALUES (?, ?)")
for k, v in summary.items():
    session.execute(ins, (k, v))

ins = session.prepare(
    "INSERT INTO genre_stats (genre, num_ratings, avg_rating) VALUES (?, ?, ?)"
)
for r in genre_stats.collect():
    session.execute(ins, (r["genre"], r["num_ratings"], float(r["avg_rating"])))

ins = session.prepare(
    "INSERT INTO top_by_genre (genre, rank, title, avg_rating, num_ratings) VALUES (?, ?, ?, ?, ?)"
)
for r in top_movies.collect():
    session.execute(
        ins, (r["genre"], r["rank"], r["title"], float(r["avg_rating"]), r["num_ratings"])
    )

print("DONE: results written to HDFS /movielens/output and Cassandra keyspace movielens")
spark.stop()
