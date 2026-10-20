"""Small read-only API + static dashboard. Data comes from Cassandra; file info from HDFS (WebHDFS)."""
import os
import time

import requests
from cassandra.cluster import Cluster
from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles

CASSANDRA_HOST = os.environ.get("CASSANDRA_HOST", "127.0.0.1")
HDFS_WEB = os.environ.get("HDFS_WEB", "http://localhost:9870")

app = FastAPI(title="MovieLens analytics")
_session = None


def db():
    """Connect lazily so the page can load even if Cassandra is still starting."""
    global _session
    if _session is None:
        try:
            _session = Cluster([CASSANDRA_HOST]).connect("movielens")
        except Exception as e:
            raise HTTPException(503, f"Cassandra not ready: {e}")
    return _session


@app.get("/api/summary")
def summary():
    rows = db().execute("SELECT metric, value FROM summary")
    return {r.metric: r.value for r in rows}


@app.get("/api/genres")
def genres():
    rows = db().execute("SELECT genre, num_ratings, avg_rating FROM genre_stats")
    out = [r._asdict() for r in rows]
    return sorted(out, key=lambda r: -r["avg_rating"])


@app.get("/api/top")
def top(genre: str = "All"):
    rows = db().execute(
        "SELECT rank, title, avg_rating, num_ratings FROM top_by_genre WHERE genre = %s",
        (genre,),
    )
    return [r._asdict() for r in rows]


@app.get("/api/hdfs")
def hdfs():
    """List the dataset directory with size and replication, straight from the namenode."""
    try:
        base = f"{HDFS_WEB}/webhdfs/v1/movielens"
        files = requests.get(f"{base}?op=LISTSTATUS", timeout=5).json()["FileStatuses"]["FileStatus"]
        out = []
        for f in files:
            out.append(
                {
                    "name": f["pathSuffix"],
                    "type": f["type"],
                    "bytes": f["length"],
                    "replication": f["replication"],
                    "block_size": f["blockSize"],
                }
            )
        return out
    except Exception as e:
        raise HTTPException(503, f"HDFS not reachable: {e}")


@app.get("/api/health")
def health():
    status = {"cassandra": False, "hdfs": False, "data_loaded": False}
    try:
        status["cassandra"] = True
        status["data_loaded"] = db().execute("SELECT metric FROM summary LIMIT 1").one() is not None
    except Exception:
        status["cassandra"] = False
    try:
        status["hdfs"] = requests.get(f"{HDFS_WEB}/webhdfs/v1/?op=LISTSTATUS", timeout=8).ok
    except Exception:
        pass
    status["time"] = int(time.time())
    return status


app.mount("/", StaticFiles(directory="static", html=True), name="static")
