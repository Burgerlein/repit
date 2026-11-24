-- Liest die BLS-4.0-Daten (MRI-xlsx) in die Seed-Datei.
-- BLSDATEI und SEEDDATEI ersetzt seed-bauen.sh vor dem Lauf (sed).
--
-- Spaltennamen gegen die echte Datei geprüft (18.11.2026, DESCRIBE auf
-- BLS_4_0_Daten_2025_DE.xlsx). Alles wird als Text gelesen, weil in den
-- Zahlenspalten »TR« (Spur, unter der Nachweisgrenze) steht: TR wird 0,
-- leer wird NULL — fehlend ist nicht null, dieselbe Regel wie überall.
-- Werte je 100 g essbarem Anteil.

INSTALL sqlite; LOAD sqlite;
INSTALL excel;  LOAD excel;
ATTACH 'SEEDDATEI' AS seed (TYPE sqlite);

CREATE OR REPLACE MACRO wert(s) AS
  CASE
    WHEN s IS NULL OR trim(s) = '' THEN NULL
    WHEN upper(trim(s)) = 'TR'     THEN 0
    ELSE try_cast(replace(trim(s), ',', '.') AS DOUBLE)
  END;

CREATE TEMP VIEW bls_roh AS
SELECT * FROM read_xlsx('BLSDATEI', header = true, all_varchar = true);

INSERT INTO seed.lebensmittel
  (quelle, schluessel, name, marke, kcal, eiweiss_g, kohlenhydrate_g,
   fett_g, zucker_g, ballaststoffe_g, gesaettigt_g, wasser_ml,
   fluessig, beliebtheit, boost)
SELECT
  'bls',
  trim("BLS Code"),
  trim("Lebensmittelbezeichnung"),
  NULL,
  wert("ENERCC Energie (Kilokalorien) [kcal/100g]"),
  wert("PROT625 Protein (Nx6,25) [g/100g]"),
  wert("CHO Kohlenhydrate, verfügbar [g/100g]"),
  wert("FAT Fett [g/100g]"),
  wert("SUGAR Zucker (Mono- und Disaccharide), gesamt [g/100g]"),
  wert("FIBT Ballaststoffe, gesamt [g/100g]"),
  wert("FASAT Fettsäuren, gesättigt, gesamt [g/100g]"),
  wert("WATER Wasser [g/100g]"),
  -- flüssig: grobe Heuristik, wirkt nur auf die Einheit im Formular
  CASE WHEN wert("WATER Wasser [g/100g]") >= 80
        AND regexp_matches(lower("Lebensmittelbezeichnung"),
            '(saft|getränk|limonade|cola|drink|tee|kaffee|bier|wein|wasser|milch)')
       THEN 1 ELSE 0 END,
  0, 0
FROM bls_roh
WHERE "Lebensmittelbezeichnung" IS NOT NULL
  AND trim("Lebensmittelbezeichnung") <> ''
  AND wert("ENERCC Energie (Kilokalorien) [kcal/100g]") IS NOT NULL;
