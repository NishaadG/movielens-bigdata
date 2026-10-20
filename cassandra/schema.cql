CREATE KEYSPACE IF NOT EXISTS movielens
  WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};

USE movielens;

-- one row per headline number (total ratings, users, movies, average rating ...)
CREATE TABLE IF NOT EXISTS summary (
  metric text PRIMARY KEY,
  value  double
);

-- average rating and volume for each genre
CREATE TABLE IF NOT EXISTS genre_stats (
  genre       text PRIMARY KEY,
  num_ratings bigint,
  avg_rating  double
);

-- top 10 movies per genre; genre = 'All' holds the overall top 10.
-- partition key = genre, clustering key = rank, so "top movies of a genre"
-- is a single-partition read already sorted by rank.
CREATE TABLE IF NOT EXISTS top_by_genre (
  genre       text,
  rank        int,
  title       text,
  avg_rating  double,
  num_ratings int,
  PRIMARY KEY (genre, rank)
) WITH CLUSTERING ORDER BY (rank ASC);

