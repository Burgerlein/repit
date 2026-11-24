#!/bin/bash
# Baut die Ernährungs-Seed-Datenbank (BLS 4.0 + populäre deutsche OFF-Produkte).
# Siehe README.md daneben. Ref #542.
set -euo pipefail

HIER="$(cd "$(dirname "$0")" && pwd)"
AUS="$HIER/aus"
SEED="$AUS/ernaehrung_seed.sqlite"
BLS=""
OFF_ANZAHL=20000
FRISCH=0

while [ $# -gt 0 ]; do
  case "$1" in
    --bls)        BLS="$2"; shift 2 ;;
    --off-anzahl) OFF_ANZAHL="$2"; shift 2 ;;
    --frisch)     FRISCH=1; shift ;;   # OFF-Teilmenge neu aus dem Netz ziehen
    *) echo "Unbekannt: $1 — bekannt sind --bls <xlsx>, --off-anzahl <n>, --frisch" >&2; exit 64 ;;
  esac
done

command -v duckdb >/dev/null || { echo "duckdb fehlt: brew install duckdb" >&2; exit 69; }
mkdir -p "$AUS"

# ── Stufe 1: OFF-Parquet holen und DE-Teilmenge filtern ──────────────────────
# Ein Download am Stück (fortsetzbar); der Remote-Scan scheitert an
# Hugging Faces Drossel für anonyme Range-Abfragen (HTTP 429).
if [ "$FRISCH" = 1 ] || [ ! -f "$AUS/food.parquet" ]; then
  # Bei --frisch die alte Datei löschen: curl -C - an einer vollständigen
  # Datei erntet HTTP 416 und bricht nach den Wiederholungen ab.
  [ "$FRISCH" = 1 ] && rm -f "$AUS/food.parquet"
  echo "OFF-Parquet herunterladen (mehrere GB, fortsetzbar) …"
  curl -L --retry 5 --retry-all-errors -C - \
    -o "$AUS/food.parquet" \
    "https://huggingface.co/datasets/openfoodfacts/product-database/resolve/main/food.parquet"
fi
if [ "$FRISCH" = 1 ] || [ ! -f "$AUS/off_de.parquet" ]; then
  echo "OFF-DE-Teilmenge filtern (bis $OFF_ANZAHL Zeilen) …"
  sed -e "s|AUSDIR|$AUS|g" -e "s|ANZAHL|$OFF_ANZAHL|g" "$HIER/off-de.sql" | duckdb
else
  echo "OFF-DE-Teilmenge liegt schon ($AUS/off_de.parquet) — --frisch erzwingt neu."
fi

# ── Stufe 2: Grundtabelle in SQLite schreiben ────────────────────────────────
# Das Schema legt sqlite3 an, nicht DuckDB: DuckDB schreibt »BIGINT PRIMARY
# KEY«, und nur ein wörtliches »INTEGER PRIMARY KEY« ist in SQLite der
# rowid-Alias, den der FTS-Index (content_rowid) braucht.
rm -f "$SEED"
echo "Grundtabelle schreiben …"
sqlite3 "$SEED" <<'SQL'
.bail on
CREATE TABLE lebensmittel (
  id INTEGER PRIMARY KEY,
  quelle TEXT NOT NULL,
  schluessel TEXT NOT NULL,
  name TEXT NOT NULL,
  marke TEXT,
  kcal REAL, eiweiss_g REAL, kohlenhydrate_g REAL, fett_g REAL,
  zucker_g REAL, ballaststoffe_g REAL, gesaettigt_g REAL, wasser_ml REAL,
  fluessig INTEGER NOT NULL,
  beliebtheit INTEGER NOT NULL,
  boost REAL NOT NULL,   -- ln(1+beliebtheit), vorgerechnet: die App-SQLite hat keine Mathe-Funktionen sicher dabei
  suchtext TEXT,
  -- `suchtext`, klein und mit Satzzeichen als Trennern: Darauf prüft der
  -- Ganzwort-Bonus der Rangfolge. Auf `suchtext` selbst scheiterte er an
  -- jedem Satzzeichen — »Karotte/Möhre, roh« enthält kein freistehendes
  -- »karotte«, und wer »Karotte« suchte, bekam das Püree. FTS tokenisiert
  -- richtig, der Bonus verglich Zeichenketten; diese Spalte schließt die
  -- Lücke zwischen beidem.
  wortfolge TEXT,
  -- Dasselbe, aber **nur aus dem Namen**. Der Ganzwort-Bonus staffelt
  -- danach: Ein Treffer im Namen wiegt schwerer als einer, der nur über
  -- ein Synonym hereinkommt. Ohne die Trennung gewann »Karotten-/
  -- Möhrenpüree« gegen »Karotte/Möhre, roh«, weil das Synonym »Möhre«
  -- per Teilstring auch »Möhrenpüree« trifft — die Synonyme sollen beim
  -- Finden helfen, nicht beim Vordrängeln.
  wortfolge_name TEXT,
  -- Die Suchbegriffe, für die genau diese Zeile der gemeinte Treffer ist
  -- (`bevorzugt.tsv`), als Wortfolge. Für die Fälle, in denen weder Name
  -- noch Synonym reichen: Wer »Ei« tippt, meint das ganze Ei und nicht
  -- das Eigelb, aber beide heißen im BLS »Hühnerei ...«.
  vorrang TEXT,
  -- Der Name **ohne Zubereitungsangabe**: »Banane roh« wird » banane «,
  -- »Teigwaren eifrei, gekocht« wird » teigwaren eifrei «. Darauf prüft
  -- der Bonus für den genauen Treffer mit.
  --
  -- Der Grund: Ohne ihn gewann die OFF-Zeile »Banane« (von Hand
  -- eingetragen, ohne Marke) gegen das BLS-Generikum »Banane roh«, weil
  -- nur sie genau so hieß. Mit ihm sind beide genaue Treffer, und die
  -- BLS-Vorliebe entscheidet — wie es die Spec will. »roh« und »gekocht«
  -- sagen etwas über die Zubereitung, nicht über ein anderes
  -- Lebensmittel; »Haferflocken-Nussplätzchen« bleibt deshalb außen vor.
  grundform TEXT
);
SQL
duckdb <<SQL
INSTALL sqlite; LOAD sqlite;
ATTACH '$SEED' AS seed (TYPE sqlite);
INSERT INTO seed.lebensmittel
  (quelle, schluessel, name, marke, kcal, eiweiss_g, kohlenhydrate_g, fett_g,
   zucker_g, ballaststoffe_g, gesaettigt_g, wasser_ml, fluessig, beliebtheit,
   boost)
  SELECT quelle, schluessel, name, marke, kcal, eiweiss_g, kohlenhydrate_g,
         fett_g, zucker_g, ballaststoffe_g, gesaettigt_g, wasser_ml,
         fluessig, beliebtheit, ln(1 + beliebtheit)
  FROM read_parquet('$AUS/off_de.parquet');
SQL

if [ -n "$BLS" ]; then
  [ -f "$BLS" ] || { echo "BLS-Datei nicht gefunden: $BLS" >&2; exit 66; }
  echo "BLS einlesen …"
  sed -e "s|BLSDATEI|$BLS|g" -e "s|SEEDDATEI|$SEED|g" "$HIER/bls-einlesen.sql" | duckdb
else
  echo "Ohne --bls: nur OFF-Teil gebaut."
fi

# ── Stufe 3: Suchtext, Synonyme, FTS5 (sqlite3, dieselbe Engine wie die App) ─
echo "Suchtext und FTS5 bauen …"
cd "$HIER"   # .import synonyme.tsv braucht das Arbeitsverzeichnis
sqlite3 "$SEED" <<'SQL'
.bail on
UPDATE lebensmittel
SET suchtext = name || coalesce(' ' || marke, '');

CREATE TEMP TABLE synonyme (muster TEXT, woerter TEXT);
.mode tabs
.import synonyme.tsv synonyme

UPDATE lebensmittel
SET suchtext = suchtext || ' ' ||
  (SELECT group_concat(s.woerter, ' ') FROM synonyme s
   WHERE lebensmittel.name LIKE '%' || s.muster || '%')
WHERE EXISTS
  (SELECT 1 FROM synonyme s WHERE lebensmittel.name LIKE '%' || s.muster || '%');

-- Die Normalisierung steckt in einer Hilfstabelle statt in vierzehn
-- verschachtelten replace() je Spalte: Dieselbe Rechnung zweimal
-- hinzuschreiben ist die nächste Stelle, an der beide auseinanderlaufen.
-- Satzzeichen zu Leerzeichen: Jede Trennstelle, die der FTS-Tokenizer
-- kennt, muss auch der Ganzwort-Bonus kennen. SQLite hat kein regexp,
-- also von Hand — die Liste deckt ab, was in BLS- und OFF-Namen vorkommt.
-- Die Vorrang-Liste: je Zeile ein Suchbegriff und der Name, der dann
-- gewinnen soll. Verglichen wird über den **vollständigen** Namen, nicht
-- über ein Muster — eine Vorrangregel, die versehentlich auf zwanzig
-- Zeilen passt, wäre schlimmer als keine.
--
-- **Quellenneutral.** Ein Versuch, den Vorrang auf BLS-Zeilen zu
-- beschränken, nahm der Liste genau die Fälle weg, für die sie gedacht
-- ist: »Mais« soll auf »Zuckermais« zeigen, und das ist eine OFF-Zeile
-- (der BLS führt unter »Mais roh« das Trockenkorn mit 336 kcal). Dass
-- mehrere Zeilen denselben Namen tragen — achtzehn heißen »Butter« —, ist
-- harmlos: Sie meinen dasselbe Lebensmittel.
--
-- **Die Begriffe wandern in den Suchtext.** Ein Bonus allein nützt nichts,
-- wenn die Suche die Zeile nicht findet: »heidelbeeren« als Präfix trifft
-- das Token »Heidelbeere« nicht, und ohne den Begriff im Index kam die
-- Zeile gar nicht erst in die Trefferliste, auf der der Bonus wirkt.
CREATE TEMP TABLE bevorzugt (begriff TEXT, ziel TEXT);
.import bevorzugt.tsv bevorzugt

UPDATE lebensmittel
SET vorrang = ' ' || (
      SELECT group_concat(lower(b.begriff), ' ')
      FROM bevorzugt b WHERE b.ziel = lebensmittel.name
    ) || ' ',
    suchtext = suchtext || ' ' || (
      SELECT group_concat(b.begriff, ' ')
      FROM bevorzugt b WHERE b.ziel = lebensmittel.name
    )
WHERE EXISTS (SELECT 1 FROM bevorzugt b WHERE b.ziel = lebensmittel.name);

UPDATE lebensmittel SET wortfolge = ' ' || trim(lower(
  replace(replace(replace(replace(replace(replace(replace(replace(replace(
  replace(replace(replace(replace(replace(suchtext,
  '/', ' '), ',', ' '), '(', ' '), ')', ' '), '.', ' '), ':', ' '),
  ';', ' '), '-', ' '), '"', ' '), '''', ' '), '!', ' '), '?', ' '),
  '%', ' '), '+', ' ')
)) || ' ';

UPDATE lebensmittel SET wortfolge_name = ' ' || trim(lower(
  replace(replace(replace(replace(replace(replace(replace(replace(replace(
  replace(replace(replace(replace(replace(name,
  '/', ' '), ',', ' '), '(', ' '), ')', ' '), '.', ' '), ':', ' '),
  ';', ' '), '-', ' '), '"', ' '), '''', ' '), '!', ' '), '?', ' '),
  '%', ' '), '+', ' ')
)) || ' ';


-- Die Zubereitungswörter des BLS. Bewusst kurz gehalten: Jedes Wort, das
-- hier zu viel steht, macht zwei verschiedene Lebensmittel zu einem.
UPDATE lebensmittel SET grundform = ' ' || trim(
  replace(replace(replace(replace(replace(replace(replace(replace(replace(
  replace(replace(replace(replace(wortfolge_name,
  ' roh ', ' '), ' gekocht ', ' '), ' gedünstet ', ' '),
  ' gebacken ', ' '), ' gebraten ', ' '), ' gegart ', ' '),
  ' gegrillt ', ' '), ' pochiert ', ' '), ' getrocknet ', ' '),
  ' frisch ', ' '), ' erhitzt ', ' '), ' geschält ', ' '),
  ' tiefgefroren ', ' ')
) || ' ';

CREATE VIRTUAL TABLE lebensmittel_fts USING fts5(
  suchtext,
  content='lebensmittel', content_rowid='id',
  tokenize='unicode61 remove_diacritics 2'
);
INSERT INTO lebensmittel_fts(rowid, suchtext)
  SELECT id, suchtext FROM lebensmittel;
INSERT INTO lebensmittel_fts(lebensmittel_fts) VALUES ('optimize');
ANALYZE;
VACUUM;
SQL

echo
echo "Fertig: $SEED"
sqlite3 "$SEED" "SELECT quelle, count(*) FROM lebensmittel GROUP BY quelle;" | sed 's/^/  /'
ls -lh "$SEED" | awk '{print "  Größe:", $5}'
