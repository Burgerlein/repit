# Ernährungs-Seed-Datenbank

Baut die mitgelieferte Lebensmittel-Datenbank des Neubaus: BLS 4.0
(Generika, deutsch) plus die populärsten deutschen Open-Food-Facts-Produkte,
als eigenständige SQLite-Datei mit fertigem FTS5-Suchindex. Entschieden in
#542; die App-Datenbank (drift-Cache) bleibt unberührt — die Seed-Datei ist
schreibgeschützt und wird beim Buchen in die eigene Tabelle kopiert, wie
OFF-Treffer heute schon.

## Quellen und Lizenzen

| Quelle | Was | Lizenz |
|---|---|---|
| BLS 4.0 (Max Rubner-Institut) | ~7.100 Generika, deutsch | kostenfrei, App-Entwicklung laut FAQ ausdrücklich erlaubt. Zitierweise: „Max Rubner-Institut (2025): Bundeslebensmittelschlüssel (BLS), Version 4.0", DOI 10.25826/Data20251217-134202-0 |
| Open Food Facts | verpackte Produkte mit Barcode | ODbL — Namensnennung in der App ist Pflicht (steht schon im Suche-Schirm) |

Die BLS-Datei `BLS_4_0_Daten_2025_DE.xlsx` muss **von Hand im Browser**
geladen werden (OpenAgrar hat eine Bot-Sperre):
<https://www.openagrar.de/servlets/MCRFileNodeServlet/openagrar_derivate_00069361/BLS_4_0_Daten_2025_DE.xlsx>

Die OFF-Teilmenge zieht DuckDB direkt aus dem offiziellen Parquet auf
Hugging Face — gefiltert auf Deutschland, sortiert nach Scan-Häufigkeit,
nur Zeilen mit Kalorienangabe. Es wird nicht der ganze Dump geladen.

## Benutzen

```bash
brew install duckdb                      # einmalig
scripts/ernaehrung-seed/seed-bauen.sh \
  --bls ~/Downloads/BLS_4_0_Daten_2025_DE.xlsx \
  --off-anzahl 20000
scripts/ernaehrung-seed/messen.sh        # Suchqualität über die Prüffälle
```

Ohne `--bls` wird nur der OFF-Teil gebaut. Ergebnis ist
`scripts/ernaehrung-seed/aus/ernaehrung_seed.sqlite`; das Verzeichnis
`aus/` steht in `.gitignore` (es enthält auch das mehrere Gigabyte große
OFF-Parquet).

**Die fertige Datei gehört ins Repository** und liegt als
`app/assets/ernaehrung_seed.sqlite` — mit einer gezielten Ausnahme von der
`*.sqlite`-Sperre, begründet in `.gitignore`: Sie ist mitgelieferter
Inhalt aus öffentlichen Quellen, keine Datenbank des Nutzers, und enthält
keine Gesundheitsdaten. Nach jedem Bau kopieren:

```bash
cp scripts/ernaehrung-seed/aus/ernaehrung_seed.sqlite \
   app/assets/ernaehrung_seed.sqlite
```

*(Bis zum 23.11.2026 stand hier, die Datei werde **nie** committet und
wandere „später" in die App — beides ist seit #543 überholt.)*

## Die drei Stellschrauben der Trefferqualität

Gemessen wird mit `messen.sh` gegen `pruef-suchen.txt`. Wer die Suche
verbessern will, greift in dieser Reihenfolge:

| Datei | Wofür | Beispiel |
|---|---|---|
| `synonyme.tsv` | Das Lebensmittel **finden**, wenn es im BLS anders heißt | `Teigwaren` → `Nudeln Pasta Spaghetti` |
| `bevorzugt.tsv` | Unter mehreren Treffern den **gemeinten** nach vorn | `ei` → `Hühnerei gekocht` |
| `off-de.sql` | Was gar nicht erst mitgeliefert wird | höchstens zwei Zeilen je Produktname |

**`bevorzugt.tsv` nennt den vollständigen Namen**, kein Muster — eine
Vorrangregel, die versehentlich auf zwanzig Zeilen passt, ist schlimmer
als keine. Vor dem Bauen prüfen, dass jedes Ziel wirklich existiert:

```bash
cut -f2 bevorzugt.tsv | sort -u | while read -r n; do
  sqlite3 -readonly aus/ernaehrung_seed.sqlite \
    "SELECT CASE WHEN count(*)=0 THEN 'FEHLT: $n' END FROM lebensmittel WHERE name='$n';"
done
```

**Die Rangfolge steht an zwei Stellen** — in `messen.sh` und in
`app/lib/ernaehrung/seed_datenbank.dart`. Sie müssen gleich bleiben,
sonst misst das Werkzeug etwas anderes als die App zeigt. Die
Dart-Fassung ist durch `app/test/ernaehrung/seed_datenbank_test.dart`
gegen die echte Datei festgenagelt; ein Seed, das die Prüffälle der Spec
nicht mehr findet, ist ein echter Befund und kein Testpflegefall.

## Aufbau der Seed-Datei

```sql
lebensmittel(id, quelle, schluessel, name, marke,
             kcal, eiweiss_g, kohlenhydrate_g, fett_g, zucker_g,
             ballaststoffe_g, gesaettigt_g, wasser_ml,
             fluessig, beliebtheit, boost, suchtext,
             wortfolge, wortfolge_name, grundform, vorrang)
lebensmittel_fts(suchtext)   -- FTS5, unicode61 remove_diacritics 2
```

- `quelle` ist `bls` oder `off`, `schluessel` der BLS-Code bzw. die EAN.
- Nährwerte je 100 g, fehlende Angaben sind NULL, **niemals 0** —
  dieselbe Regel wie im drift-Cache.
- `suchtext` ist Name + Marke + Synonyme + Vorrang-Begriffe, darauf läuft
  die FTS-Suche. `synonyme.tsv` ist von Hand gepflegt und fängt die
  deutschen Komposita-Fälle („Toast" → „Toastbrot", „hartgekochtes Ei" →
  „Hühnerei gekocht").
- **Die vier Wortfolge-Spalten tragen die Rangfolge.** FTS tokenisiert an
  Satzzeichen, ein Zeichenketten-Vergleich nicht — »Karotte/Möhre, roh«
  enthält kein freistehendes »karotte«, und wer »Karotte« suchte, bekam
  das Püree. Deshalb normalisiert der Bau vor:
  `wortfolge` (Name + Marke + Synonyme), `wortfolge_name` (nur der Name),
  `grundform` (Name ohne »roh«, »gekocht« und die übrigen
  Zubereitungswörter) und `vorrang` (die Begriffe aus `bevorzugt.tsv`).
  Gestaffelt wird so: Vorrang schlägt genauen Namen, genauer Name schlägt
  Wort im Namen, Wort im Namen schlägt Synonym. Ohne die Staffelung
  gewann »Karotten-/Möhrenpüree«, weil das Synonym »Möhre« per Teilstring
  auch »Möhrenpüree« trifft — Synonyme sollen beim Finden helfen, nicht
  beim Vordrängeln.

## Messen

`messen.sh` läuft die Suchen aus `pruef-suchen.txt` gegen die Seed-Datei
und druckt je Suche die fünf besten Treffer. Neue Fehlschläge aus der
echten Benutzung gehören als Zeile in `pruef-suchen.txt`, Abhilfen als
Zeile in `synonyme.tsv` — beides committen.
