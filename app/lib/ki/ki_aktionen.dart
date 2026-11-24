// Der Ausführer der KI-Aktionen (#330, #341): Was die KI vorschlägt, wird
// hier — und nur hier — zur Tatsache.
//
// API und Vertrag sind durch `app/test/ki/ki_aktionen_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// **Die KI legt nichts selbst an.** Ihre Antwort ist ein `KiVorschlag`;
// ausgeführt wird er auf Tims Tipp im Prüfblatt, und von keiner anderen
// Stelle (Spec `2026-11-04-ki-zugang-design.md`, „Die Aktionsliste").
// Ein Wächterfall im Test sucht nach weiteren Aufrufern.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/ernaehrung_repository.dart';
import '../ernaehrung/erfassen_provider.dart';

/// Der **einzige** Ausführer eines [KiVorschlag]s. Ein `Notifier`, kein
/// `Provider` mit gehaltenem `Ref` (`CLAUDE.md`, Hausregel 3).
final kiAktionenProvider = NotifierProvider<KiAktionen, void>(KiAktionen.new);

class KiAktionen extends Notifier<void> {
  @override
  void build() {}

  /// Führt [vorschlag] aus. Aufgerufen nur vom Knopf im Prüfblatt.
  ///
  /// Der `switch` über die versiegelte [KiAktion] ist vollständig: Kommt
  /// eine zweite Aktion in den Kern, zeigt der Analyzer auf diese Stelle.
  Future<void> fuehreAus(KiVorschlag vorschlag) async {
    switch (vorschlag.aktion) {
      case final EintraegeBuchen aktion:
        await _bucheEintraege(aktion, vorschlag.herkunft);
    }
  }

  /// Je **übernommener** Posten ein Eintrag — gefiltert wird hier, nicht
  /// beim Aufrufer: Ein unsicherer, unberührter Posten lässt sich so auf
  /// keinem Weg buchen, gleich, was das Prüfblatt übergibt. `uebernommen`
  /// ist idempotent; ein schon gefilterter Vorschlag bucht dasselbe.
  ///
  /// Tag, Mahlzeit und Uhrzeit kommen aus der Aktion, nicht aus der Uhr
  /// und nicht aus dem Antwortzeitpunkt — der ist Herkunft. Die Nährwerte
  /// werden eingefroren, wie sie im Posten stehen; was fehlt, bleibt
  /// `null`.
  Future<void> _bucheEintraege(
    EintraegeBuchen aktion,
    KiHerkunft herkunft,
  ) async {
    final text = jsonEncode(herkunft.alsJson());
    final eintraege = [
      for (final posten in uebernommen(aktion.posten))
        Eintrag(
          tagesSchluessel: aktion.tagesSchluessel,
          mahlzeit: aktion.mahlzeit,
          zeitpunkt: aktion.zeitpunkt,
          name: posten.name,
          mengeG: posten.gramm,
          naehrwerte: posten.werte,
          vorschlag: text,
        ),
    ];
    await ref.read(erfassenProvider.notifier).bucheBestaetigt(eintraege);
  }
}
