const $ = (id) => document.getElementById(id);
const nf = new Intl.NumberFormat("en-US");

async function get(path) {
  const r = await fetch(path);
  if (!r.ok) throw new Error(path + " -> " + r.status);
  return r.json();
}

function humanBytes(n) {
  if (n < 1024) return n + " B";
  if (n < 1024 ** 2) return (n / 1024).toFixed(1) + " KB";
  if (n < 1024 ** 3) return (n / 1024 ** 2).toFixed(1) + " MB";
  return (n / 1024 ** 3).toFixed(2) + " GB";
}

function el(tag, cls, text) {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text !== undefined) e.textContent = text;
  return e;
}

/* ---------- status + headline figures ---------- */
async function loadStatus() {
  const ul = $("status");
  try {
    const h = await get("/api/health");
    ul.replaceChildren();
    [["HDFS", h.hdfs], ["Cassandra", h.cassandra], ["Results loaded", h.data_loaded]].forEach(([n, ok]) => {
      const li = el("li", ok ? "ok" : "", n);
      ul.append(li);
    });
    return h.data_loaded;
  } catch {
    ul.replaceChildren(el("li", "", "API unreachable"));
    return false;
  }
}

async function loadSummary() {
  const s = await get("/api/summary");
  $("lede").textContent =
    nf.format(s.total_ratings) + " ratings of " + nf.format(s.total_movies) + " movies, processed with Hadoop, Spark and Cassandra.";
  $("min-ratings").textContent = nf.format(s.min_ratings);
  const figs = [
    [nf.format(s.total_ratings), "ratings"],
    [nf.format(s.total_users), "users"],
    [s.avg_rating.toFixed(2), "average rating (out of 5)"],
    [Math.round((s.high_ratings / s.total_ratings) * 100) + "%", "of ratings are 4 stars or more"],
  ];
  $("figures").replaceChildren(
    ...figs.map(([v, l]) => {
      const d = el("div", "fig");
      d.append(el("div", "v", v), el("div", "l", l));
      return d;
    })
  );
}

/* ---------- genre dot plot ---------- */
async function loadGenres() {
  const data = await get("/api/genres");
  const vals = data.map((d) => d.avg_rating);
  const lo = Math.floor((Math.min(...vals) - 0.05) * 10) / 10;
  const hi = Math.ceil((Math.max(...vals) + 0.05) * 10) / 10;
  const pos = (v) => ((v - lo) / (hi - lo)) * 100;
  const ticks = [];
  for (let t = lo; t <= hi + 1e-9; t += 0.2) ticks.push(+t.toFixed(1));

  const box = $("genres");
  box.replaceChildren();

  const axis = el("div", "dot-axis");
  const scale = el("div", "scale");
  ticks.forEach((t) => {
    const s = el("span", "", t.toFixed(1));
    s.style.left = pos(t) + "%";
    scale.append(s);
  });
  axis.append(el("div"), scale, el("div"));
  box.append(axis);

  data.forEach((d) => {
    const row = el("div", "dot-row");
    row.title = nf.format(d.num_ratings) + " ratings";
    const track = el("div", "track");
    ticks.forEach((t) => {
      const k = el("div", "tick");
      k.style.left = pos(t) + "%";
      track.append(k);
    });
    const stem = el("div", "stem");
    stem.style.left = "0";
    stem.style.width = pos(d.avg_rating) + "%";
    const pt = el("div", "pt");
    pt.style.left = pos(d.avg_rating) + "%";
    track.append(stem, pt);
    row.append(el("div", "name", d.genre), track, el("div", "val", d.avg_rating.toFixed(2)));
    box.append(row);
  });
}

/* ---------- top movies, per genre ---------- */
async function loadTop(genre) {
  const rows = await get("/api/top?genre=" + encodeURIComponent(genre));
  const tb = document.querySelector("#top tbody");
  tb.replaceChildren();
  if (!rows.length) {
    const tr = el("tr");
    const td = el("td", "empty", "No movie in this genre has enough ratings.");
    td.colSpan = 4;
    tr.append(td);
    tb.append(tr);
    return;
  }
  rows.forEach((r) => {
    const tr = el("tr");
    tr.append(el("td", "num", r.rank), el("td", "", r.title), el("td", "num", r.avg_rating.toFixed(2)), el("td", "num", nf.format(r.num_ratings)));
    tb.append(tr);
  });
}

async function setupTop() {
  const sel = $("genre-select");
  const genres = (await get("/api/genres")).map((g) => g.genre).sort();
  ["All", ...genres].forEach((g) => sel.append(new Option(g === "All" ? "All genres" : g, g)));
  sel.addEventListener("change", () => loadTop(sel.value));
  loadTop("All");
}

/* ---------- HDFS files ---------- */
async function loadHdfs() {
  const tb = document.querySelector("#hdfs tbody");
  try {
    const files = await get("/api/hdfs");
    tb.replaceChildren();
    files.forEach((f) => {
      const tr = el("tr");
      const isDir = f.type === "DIRECTORY";
      tr.append(el("td", "", f.name), el("td", "", isDir ? "folder" : "file"), el("td", "num", isDir ? "" : humanBytes(f.bytes)), el("td", "num", isDir ? "" : f.replication));
      tb.append(tr);
    });
  } catch {
    const tr = el("tr");
    const td = el("td", "empty", "HDFS is not reachable.");
    td.colSpan = 4;
    tr.append(td);
    tb.replaceChildren(tr);
  }
}

/* ---------- start ---------- */
(async function init() {
  const loaded = await loadStatus();
  loadHdfs();
  if (!loaded) {
    $("lede").textContent = "No results yet. Run the Spark job first (see README), then reload this page.";
    return;
  }
  try {
    await Promise.all([loadSummary(), loadGenres(), setupTop()]);
  } catch (e) {
    $("lede").textContent = "Could not load results: " + e.message;
  }
})();
