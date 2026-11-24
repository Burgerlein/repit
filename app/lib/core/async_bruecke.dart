import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'messwert.dart';

/// Die **einzige** Stelle, an der ein `AsyncValue` in einen `Messwert`
/// übergeht (Spec 5.4). Views und Stores arbeiten ab hier nur noch mit
/// `Messwert<T>` — nirgends sonst darf `AsyncValue` auftauchen.
///
/// `cache` kommt als **ein** Stück herein, nicht als zwei unabhängig
/// nullbare Teile (Spec 5.3d): Wert und Stand gehören zusammen, und eine
/// Signatur, die sie getrennt nullbar macht, lässt Zustände zu, die der
/// Vertrag für unmöglich hält — „Stand da, Wert null" und umgekehrt.
///
/// Die sieben Fälle aus der Tabelle in Spec 5.3d, ohne Rückfall:
///
/// | `v`      | `cache` | Ergebnis                                        |
/// |----------|---------|--------------------------------------------------|
/// | lädt     | `null`  | `NochNie`                                        |
/// | lädt     | da      | `Bekannt(cache.wert, stand: cache.stand, laeuft: true)` |
/// | Fehler   | `null`  | `Fehlgeschlagen(gelaufen: jetzt)`                |
/// | Fehler   | da      | `Bekannt(cache.wert, stand: cache.stand, laeuft: false)` |
/// | fertig, `istLeer` oder `v.value == null` | `null` | `LeerNachLauf(gelaufen: jetzt)` |
/// | fertig, `istLeer` oder `v.value == null` | da | `Bekannt(cache.wert, stand: cache.stand, laeuft: false)` |
/// | fertig, Wert da | —  | `Bekannt(v.value!, stand: jetzt, laeuft: false)` |
///
/// Drei Entscheidungen darin:
///
/// - **Ein frisch geholter Wert trägt `stand: jetzt`**, nicht den
///   Cache-Stand. Er stammt von gerade eben, und das ist, was der Nutzer als
///   „Stand 14:32" liest. Der Cache-Stand gilt nur für Werte, die tatsächlich
///   aus dem Cache kommen (die drei Zeilen mit `cache: da` oben).
/// - **Ein `null`-Wert gilt als leer**, unabhängig von `istLeer` — damit gibt
///   es keinen Pfad mehr, auf dem die Brücke einen ungeprüften Cast werfen
///   könnte.
/// - **Ein leerer Lauf nimmt keinen zwischengespeicherten Wert weg** (#224,
///   Tim am 03.11.2026): Mit Cache endet er genauso wie ein gescheiterter
///   Lauf, `LeerNachLauf` gilt nur noch **ohne** Cache. Apple verrät den
///   Lesestatus nicht — „keine Daten" und „nicht erlaubt" sind nicht
///   unterscheidbar, und eine entzogene Freigabe liefert alle Reihen leer,
///   aber **erfolgreich**. Vorher nahm das sämtliche zwischengespeicherten
///   Werte auf einen Schlag mit, und „Werte verschwinden" ist Tims
///   ursprüngliche Beschwerde. **Der Preis ist benannt und angenommen:**
///   Ein wirklich gelöschter Health-Eintrag bleibt stehen, bis ein Lauf
///   etwas anderes findet. Das ist die kleinere Lüge.
///
/// **Die Stand-Zeile bleibt dabei ehrlich**, und zwar auf beiden Ebenen:
/// Hier trägt der stehengebliebene Wert `cache.stand`, nie `jetzt` — sonst
/// behauptete die Zeile einen Lauf, der diesen Wert nie gesehen hat. Und
/// unterhalb davon schreibt ein leerer Lauf nichts in den Cache zurück
/// (`CacheRepository.schreibeTagesWerte`/`schreibeNaechte`/
/// `schreibeNachtWerte` kehren bei leerer Eingabe sofort zurück), das alte
/// `gelesenAm` bleibt also auch über einen Kaltstart stehen.
///
/// **`isLoading` wird zuerst geprüft und gewinnt gegen `hasError`** (Spec
/// 5.3e) — Absicht, nicht Zufall der Zweigreihenfolge: Während eines
/// Wiederholungslaufs (5.3c) ist ein `AsyncValue` zugleich `isLoading` und
/// `hasError`, und ein laufender Versuch ist noch kein Ergebnis. Wer einen
/// Cache hat, sieht ihn weiter mit `laeuft: true`; wer keinen hat, sieht den
/// Platzhalter `NochNie` statt `Fehlgeschlagen`.
///
/// **Was diese Brücke nicht leisten kann:** Dass `Bekannt` nie leere Daten
/// trägt, kann sie bei generischem `T` nicht selbst durchsetzen — genau
/// deshalb gibt es `istLeer`. Sie **verlässt sich** auf dieses vom Aufrufer
/// gelieferte Flag, sie prüft `T` nicht.
///
/// `jetzt` kommt von außen herein und wird nicht aus `DateTime.now()`
/// geholt, damit diese Funktion deterministisch testbar bleibt.
Messwert<T> alsMesswert<T>(
  AsyncValue<T?> v, {
  required ({T wert, DateTime stand})? cache,
  required DateTime jetzt,
  required bool istLeer,
}) {
  if (v.isLoading) {
    if (cache == null) {
      return NochNie<T>();
    }
    return Bekannt<T>(cache.wert, stand: cache.stand, laeuft: true);
  }

  if (v.hasError) {
    if (cache == null) {
      return Fehlgeschlagen<T>(fehler: v.error!, gelaufen: jetzt);
    }
    return Bekannt<T>(cache.wert, stand: cache.stand, laeuft: false);
  }

  final wert = v.value;
  if (istLeer || wert == null) {
    if (cache == null) {
      return LeerNachLauf<T>(gelaufen: jetzt);
    }
    return Bekannt<T>(cache.wert, stand: cache.stand, laeuft: false);
  }
  return Bekannt<T>(wert, stand: jetzt, laeuft: false);
}
