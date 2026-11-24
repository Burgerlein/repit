// Der **Abruf der Portionen beim Antippen** (#398, unter #325): welcher
// Treffer bei Open Food Facts nachfragt, wie oft, und was eine Antwort
// hinterlässt.
//
// Spec: `docs/superpowers/specs/2026-11-05-portionen-design.md`, Abschnitt
// „Abruf beim Antippen", dazu V3 und V4. API und Vertrag sind durch
// `app/test/ernaehrung/portions_abruf_test.dart` vorgegeben (siehe dessen
// Dateikopf) — diese Datei darf die Tests ausführen, aber nicht verändern
// (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die Implementierung").
//
// **Höchstens eine Anfrage je Öffnen des Buchungsblatts.** Der
// Strichcode-Endpunkt antwortet nach etwa 20 schnellen Anfragen mit
// HTTP 429. Deshalb gibt es hier keine Wiederholung, keinen
// Zwischenspeicher über das Blatt hinaus und keinen Abruf für eine
// Trefferliste — nur den einen Treffer, den Tim angetippt hat.
//
// **Kein `AsyncValue` und kein `Messwert`.** Der Abruf hat einen eigenen
// sealed-Typ: Er ist kein Lauf aus Apple Health, sondern eine einzelne
// Anfrage mit Antwort oder ohne (`CLAUDE.md`, Hausregel 1).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/lebensmittel_repository.dart';
import '../data/portion.dart';
import '../data/portionen_repository.dart';
import '../health/health_provider.dart';
import 'off_client.dart';

/// Wonach gefragt wird: der Strichcode, und bei einem schon übernommenen
/// Produkt sein Schlüssel in `lebensmittel`.
///
/// **Werttyp mit [==] und [hashCode]** — das Argument der Familie. Zwei
/// Widgets desselben Blatts bauen je ihre eigene Quelle aus der Vorlage;
/// ohne Wertgleichheit wären das zwei Abrufe und zwei Anfragen.
@immutable
class PortionsQuelle {
  const PortionsQuelle({required this.barcode, this.lebensmittelId});

  final String barcode;

  /// `null` bei einem Online-Treffer, der noch nicht in der eigenen
  /// Tabelle steht. Dann schreibt der Abruf nichts (V3).
  final int? lebensmittelId;

  @override
  bool operator ==(Object other) =>
      other is PortionsQuelle &&
      other.barcode == barcode &&
      other.lebensmittelId == lebensmittelId;

  @override
  int get hashCode => Object.hash(barcode, lebensmittelId);

  @override
  String toString() =>
      'PortionsQuelle(barcode: $barcode, lebensmittelId: $lebensmittelId)';
}

/// Ob ein angetipptes Lebensmittel bei Open Food Facts nachfragt — und
/// wonach. Genau die zwei Fälle aus der Spec-Tabelle, sonst `null`:
///
/// - **Online-Treffer, noch nicht übernommen** (Entscheidung 5): ohne
///   Schlüssel, Herkunft `off`, Portionen nicht abgefragt
///   (`offPortionen == null`). Ein gescanntes Produkt fragt nicht, seine
///   Antwort kam mit dem Scan, auch wenn sie „keine" lautete.
/// - **Schon übernommen, nie gefragt** (Entscheidung 6): mit Schlüssel,
///   Herkunft `off`, mit Strichcode, `portionenAbgefragtAm == null`.
///
/// Ein eigenes Lebensmittel fragt nie, auch mit Strichcode nicht: Die
/// Werte hat Tim von der Packung abgeschrieben.
PortionsQuelle? brauchtAbruf(LebensmittelVorlage v) {
  final barcode = v.barcode;
  if (barcode == null || v.herkunft != Herkunft.off) return null;
  final id = v.id;
  if (id == null) {
    return v.offPortionen == null ? PortionsQuelle(barcode: barcode) : null;
  }
  return v.portionenAbgefragtAm == null
      ? PortionsQuelle(barcode: barcode, lebensmittelId: id)
      : null;
}

/// Wie der Abruf steht.
///
/// **„Gescheitert" ist nicht „keine Portion".** [AbrufGescheitert] heißt,
/// niemand hat nachgesehen; [AbrufFertig] mit `[]` heißt, Open Food Facts
/// hat geantwortet und kennt keine.
sealed class PortionsAbruf {
  const PortionsAbruf();
}

/// Die Anfrage läuft.
final class AbrufLaeuft extends PortionsAbruf {
  const AbrufLaeuft();

  @override
  bool operator ==(Object other) => other is AbrufLaeuft;

  @override
  int get hashCode => (AbrufLaeuft).hashCode;

  @override
  String toString() => 'AbrufLaeuft()';
}

/// Open Food Facts hat geantwortet.
///
/// Bei einem übernommenen Produkt stehen hier die Portionen **aus der
/// Tabelle**, samt Schlüssel und samt den eigenen — damit eine gewählte
/// Portion beim Buchen ihre `portion_id` hat. Bei einem Online-Treffer
/// die gefilterten Portionen aus der Antwort, ohne Schlüssel.
final class AbrufFertig extends PortionsAbruf {
  const AbrufFertig({required this.portionen, required this.fluessig});

  final List<Portion> portionen;

  /// Ob die Antwort Milliliter nennt (Entscheidung 10).
  final bool fluessig;

  @override
  bool operator ==(Object other) =>
      other is AbrufFertig &&
      other.fluessig == fluessig &&
      listEquals(other.portionen, portionen);

  @override
  int get hashCode => Object.hash(Object.hashAll(portionen), fluessig);

  @override
  String toString() =>
      'AbrufFertig(portionen: $portionen, fluessig: $fluessig)';
}

/// Keine Antwort: kein Netz, Zeitüberschreitung, HTTP 429 oder sonst ein
/// Fehler (V4). Das nächste Öffnen fragt erneut.
final class AbrufGescheitert extends PortionsAbruf {
  const AbrufGescheitert();

  @override
  bool operator ==(Object other) => other is AbrufGescheitert;

  @override
  int get hashCode => (AbrufGescheitert).hashCode;

  @override
  String toString() => 'AbrufGescheitert()';
}

/// Der Abruf zu einer [PortionsQuelle].
///
/// **`autoDispose` ist Pflicht.** „Eine je Öffnen" heißt wörtlich, dass ein
/// neues Öffnen neu fragt; ohne `autoDispose` hielte der Behälter das
/// Ergebnis über das Blatt hinaus, und ein gescheiterter Abruf bliebe
/// gescheitert, bis die App neu startet. Zwei Leser desselben Blatts
/// teilen sich den einen Abruf.
final portionsAbrufProvider = NotifierProvider.autoDispose
    .family<PortionsAbrufNotifier, PortionsAbruf, PortionsQuelle>(
      PortionsAbrufNotifier.new,
    );

class PortionsAbrufNotifier extends Notifier<PortionsAbruf> {
  PortionsAbrufNotifier(this.quelle);

  final PortionsQuelle quelle;

  /// Gibt [AbrufLaeuft] zurück und stößt **genau eine** Anfrage an.
  /// `build` läuft je Abruf einmal; eine Wiederholung gibt es nicht.
  @override
  PortionsAbruf build() {
    // Alles, was nach dem `await` noch gebraucht wird, vorher holen:
    // Schließt das Blatt, bevor die Antwort da ist, wird die Nachfrage
    // eines übernommenen Produkts trotzdem eingetragen — sonst fragte das
    // nächste Öffnen eine Antwort ab, die es schon gab.
    unawaited(
      _frage(
        client: ref.read(offClientProvider),
        lebensmittel: ref.read(lebensmittelRepositoryProvider),
        portionen: ref.read(portionenRepositoryProvider),
        uhr: ref.read(clockProvider),
      ),
    );
    return const AbrufLaeuft();
  }

  Future<void> _frage({
    required OffClient client,
    required LebensmittelRepository lebensmittel,
    required PortionenRepository portionen,
    required DateTime Function() uhr,
  }) async {
    PortionsAbruf ergebnis;
    try {
      final antwort = await client.produktZuBarcode(quelle.barcode);
      final (liste, fluessig) = switch (antwort) {
        Treffer(:final produkte) => (
          produkte.first.portionen ?? const <Portion>[],
          produkte.first.fluessig,
        ),
        NichtGefunden() => (const <Portion>[], false),
        // V4: keine Antwort, keine Marke. Das nächste Öffnen fragt wieder.
        KeinNetz() => (null, false),
      };
      if (liste == null) {
        ergebnis = const AbrufGescheitert();
      } else {
        ergebnis = await _fertig(
          liste,
          fluessig: fluessig,
          lebensmittel: lebensmittel,
          portionen: portionen,
          uhr: uhr,
        );
      }
    } catch (fehler) {
      debugPrint('Portionen von Open Food Facts: $fehler');
      ergebnis = const AbrufGescheitert();
    }
    if (ref.mounted) state = ergebnis;
  }

  /// Eine Antwort ist da. Ein Online-Treffer schreibt nichts (V3); ein
  /// übernommenes Produkt trägt sie nach (Entscheidung 6, V5) und liefert
  /// danach seine Portionen aus der Tabelle.
  Future<AbrufFertig> _fertig(
    List<Portion> liste, {
    required bool fluessig,
    required LebensmittelRepository lebensmittel,
    required PortionenRepository portionen,
    required DateTime Function() uhr,
  }) async {
    final id = quelle.lebensmittelId;
    if (id == null) return AbrufFertig(portionen: liste, fluessig: fluessig);

    await lebensmittel.trageOffPortionenNach(
      id,
      portionen: liste,
      fluessig: fluessig,
      jetzt: uhr(),
    );
    return AbrufFertig(portionen: await portionen.fuer(id), fluessig: fluessig);
  }
}
