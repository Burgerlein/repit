#!/bin/bash
# Läuft die Suchen aus pruef-suchen.txt gegen die Seed-Datei und druckt
# je Suche die fünf besten Treffer. Neue Fehlschläge aus der echten
# Benutzung gehören als Zeile in pruef-suchen.txt. Ref #542.
set -euo pipefail

HIER="$(cd "$(dirname "$0")" && pwd)"
SEED="$HIER/aus/ernaehrung_seed.sqlite"
[ -f "$SEED" ] || { echo "Seed fehlt — erst seed-bauen.sh laufen lassen." >&2; exit 66; }

# Rangfolge = Textnähe (bm25, kleiner ist besser)
#   − Beliebtheits-Boost (OFF-Scans, vorgerechnet)
#   − Ganzwort-Bonus (die Suche steht wörtlich im Namen: »Banane« trifft
#     »Banane roh« vor »Bananennektar«)
#   − Generika-Bonus für BLS (wer »Paprika« tippt, meint eher das Gemüse
#     als die Chips)
#   + kleine Strafe je Namenslänge (kürzer = grundlegender)
# Dieselbe Formel gehört später in den Seed-Such-Provider der App.
suche_eine() {
  local match="$1" wort="$2"
  sqlite3 -readonly "$SEED" "
    SELECT printf('  %-4s %5s  %s', l.quelle,
                  coalesce(CAST(CAST(round(l.kcal) AS INT) AS TEXT), '–'),
                  substr(l.name || coalesce(' · ' || l.marke, ''), 1, 60))
    FROM lebensmittel_fts f JOIN lebensmittel l ON l.id = f.rowid
    WHERE lebensmittel_fts MATCH '$match'
    ORDER BY bm25(lebensmittel_fts)
             - 0.3 * l.boost
             - (CASE WHEN instr(coalesce(l.vorrang,''), ' ' || lower('$wort') || ' ') > 0 THEN 12.0 ELSE 0 END)
             - (CASE WHEN l.wortfolge_name = ' ' || lower('$wort') || ' '
                      OR l.grundform = ' ' || lower('$wort') || ' '
                    THEN 6.0 ELSE 0 END)
             - (CASE WHEN instr(l.wortfolge_name, ' ' || lower('$wort') || ' ') > 0 THEN 4.0 ELSE 0 END)
             - (CASE WHEN instr(l.wortfolge, ' ' || lower('$wort') || ' ') > 0 THEN 1.5 ELSE 0 END)
             - (CASE WHEN l.quelle = 'bls' THEN 1.5 ELSE 0 END)
             + (CASE WHEN l.kcal = 0 AND l.fluessig = 0 THEN 2.0 ELSE 0 END)
             + 0.45 * (length(l.wortfolge_name)
                       - length(replace(l.wortfolge_name, ' ', '')) - 1)
    LIMIT 5;"
}

while IFS= read -r suche; do
  [ -z "$suche" ] && continue
  # Apostrophe fürs SQL-Literal verdoppeln (»Kellogg's«), Anführungszeichen raus
  sicher=$(printf '%s' "$suche" | sed "s/'/''/g; s/\"//g")
  # jedes Wort als Präfix: »gekochtes Ei« → "gekochtes"* "ei"*
  und=$(printf '%s' "$sicher" | tr -s ' ' '\n' | sed 's/^/"/; s/$/"*/' | paste -sd' ' -)
  oder=$(printf '%s' "$sicher" | tr -s ' ' '\n' | sed 's/^/"/; s/$/"*/' | paste -sd'|' - | sed 's/|/ OR /g')
  echo "== $suche"
  treffer=$(suche_eine "$und" "$sicher")
  if [ -z "$treffer" ] && [ "$und" != "$oder" ]; then
    treffer=$(suche_eine "$oder" "$sicher")
    [ -n "$treffer" ] && echo "  (nur Teiltreffer)"
  fi
  if [ -n "$treffer" ]; then printf '%s\n' "$treffer"; else echo "  — nichts —"; fi
  echo
done < "$HIER/pruef-suchen.txt"
