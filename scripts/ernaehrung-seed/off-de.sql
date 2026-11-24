-- Filtert die deutsche OFF-Teilmenge aus dem offiziellen Parquet.
-- AUSDIR und ANZAHL ersetzt seed-bauen.sh vor dem Lauf (sed); das Parquet
-- lädt seed-bauen.sh vorher am Stück herunter — Hugging Face drosselt die
-- vielen Range-Abfragen eines Remote-Scans (HTTP 429), einen einzelnen
-- Download nicht.

CREATE OR REPLACE MACRO n100(ns, nm) AS
  list_filter(ns, lambda x: x.name = nm)[1]['100g'];

COPY (
  WITH de AS (
    SELECT
      code,
      coalesce(
        list_filter(product_name, lambda x: x.lang = 'de')[1]['text'],
        list_filter(product_name, lambda x: x.lang = 'main')[1]['text']
      ) AS name,
      brands,
      coalesce(unique_scans_n, 0) AS beliebtheit,
      quantity,
      n100(nutriments, 'energy-kcal')                         AS kcal_direkt,
      n100(nutriments, 'energy') / 4.184                      AS kcal_aus_kj,
      n100(nutriments, 'proteins')                            AS eiweiss_g,
      n100(nutriments, 'carbohydrates')                       AS kohlenhydrate_g,
      n100(nutriments, 'fat')                                 AS fett_g,
      n100(nutriments, 'sugars')                              AS zucker_g,
      n100(nutriments, 'fiber')                               AS ballaststoffe_g,
      n100(nutriments, 'saturated-fat')                       AS gesaettigt_g
    FROM 'AUSDIR/food.parquet'
    WHERE list_contains(countries_tags, 'en:germany')
      AND coalesce(obsolete, false) = false
  )
  SELECT
    'off'                          AS quelle,
    code                           AS schluessel,
    trim(name)                     AS name,
    nullif(trim(brands), '')       AS marke,
    coalesce(kcal_direkt, kcal_aus_kj) AS kcal,
    eiweiss_g, kohlenhydrate_g, fett_g, zucker_g,
    ballaststoffe_g, gesaettigt_g,
    CAST(NULL AS DOUBLE)           AS wasser_ml,
    -- **Flüssig oder nicht** — zwei Wege, weil einer nicht reicht:
    -- Die Mengenangabe fehlt bei vielen Zeilen oder steht als »6x0,33«,
    -- und dann galt »Coca Cola Zero« als feste Nahrung. Das traf zweimal:
    -- Die Einheit im Buchungsformular wäre Gramm statt Milliliter, und
    -- der Malus für »0 kcal bei fester Nahrung« (gegen kaputte Zeilen wie
    -- »Walnüsse, 0 kcal«) hätte ausgerechnet die Zero-Getränke bestraft,
    -- bei denen die Null stimmt.
    --
    -- Die Wortliste ist bewusst knapp und meint das Getränk selbst, nicht
    -- seinen Rohstoff: »Kaffeebohnen« und »Teebeutel« bleiben fest, weil
    -- »bohnen« und »beutel« nicht darin vorkommen.
    CASE
      WHEN regexp_matches(lower(coalesce(quantity, '')), '\d\s*(ml|cl|l)\b')
        THEN 1
      WHEN regexp_matches(
             lower(coalesce(name, '')),
             '(cola|limonade|limo\b|schorle|saft\b|nektar|eistee|'
             || 'mineralwasser|tafelwasser|spezi|fanta|sprite|'
             || 'energy.?drink|smoothie|getränk|brause\b)'
           ) THEN 1
      ELSE 0
    END                            AS fluessig,
    beliebtheit
  FROM de
  WHERE name IS NOT NULL AND length(trim(name)) >= 2
    AND coalesce(kcal_direkt, kcal_aus_kj) IS NOT NULL
    AND coalesce(kcal_direkt, kcal_aus_kj) BETWEEN 0 AND 1000
  -- **Gleiches Produkt nur einmal.** Open Food Facts führt dasselbe
  -- Lebensmittel oft mehrfach — fünf Zeilen hießen schlicht »Toast« und
  -- besetzten die ersten fünf Plätze, sodass »Toastbrot« aus der Liste
  -- fiel. Zusammengefasst wird über Name, Marke und gerundete Kalorien;
  -- bleibt die beliebteste Zeile, also die mit den meisten Scans.
  --
  -- Das ist nicht dieselbe Entdopplung wie `LebensmittelDubletten` in der
  -- App: Die arbeitet über die Trefferliste zur Laufzeit und fasst auch
  -- ähnliche Namen zusammen. Hier geht es nur um das offensichtliche
  -- Doppelte im Bestand, damit es gar nicht erst mitgeliefert wird.
  -- Erstens: dieselbe Marke mit denselben Werten nur einmal.
  -- Zweitens: **höchstens zwei Zeilen je Name.** Fünf Marken-Toasts
  -- zwischen 223 und 269 kcal sind für den, der »Toast« sucht,
  -- austauschbar — sie besetzten aber die ersten fünf Plätze, und
  -- »Toastbrot« fiel aus der Liste. Zwei statt einer, damit eine
  -- offensichtlich kaputte Zeile nicht die einzige ihres Namens ist.
  QUALIFY row_number() OVER (
            PARTITION BY lower(trim(name)),
                         lower(coalesce(trim(brands), '')),
                         round(coalesce(kcal_direkt, kcal_aus_kj))
            ORDER BY beliebtheit DESC, code
          ) = 1
      AND row_number() OVER (
            PARTITION BY lower(trim(name))
            ORDER BY beliebtheit DESC, code
          ) <= 2
  ORDER BY beliebtheit DESC
  LIMIT ANZAHL
) TO 'AUSDIR/off_de.parquet' (FORMAT parquet);
