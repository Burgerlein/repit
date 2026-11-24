import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/schlaf_eintrag.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/schlaf_zustand.dart';

/// Tests für die **von Hand eingetragene Nacht im Zustand des
/// Schlaf-Schirms** (#131, Zug 3) — `schlafZustandAus` in
/// `lib/shell/schlaf_zustand.dart` und die Verschmelzung in
/// `lib/shell/schlaf_von_hand.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## Die Entscheidung, um die es hier geht
///
/// Was passiert, wenn für denselben Aufwachtag **beides** vorliegt — eine
/// gemessene Nacht und eine eingetragene? Der Entwurf beantwortet es:
///
/// > Die Nacht liegt also in der App und wird beim Lesen **über die
/// > Health-Daten gelegt** — dieselbe Regel wie bei den Umfängen
/// > („Eingetippte Werte schlagen importierte", SPEC 4.6).
///
/// Also: **Der Eintrag gewinnt, und zwar ganz.** Nicht halb, nicht als
/// Ergänzung einzelner Felder. Eine Nacht ist eine Aussage über die ganze
/// Nacht; eine aus gemessener Dauer und eingetippter Einschlafzeit
/// zusammengesetzte Nacht hätte es so nie gegeben, und niemand könnte
/// hinterher sagen, welche Zahl woher kommt. Rückgängig ist es trotzdem:
/// Wer den Eintrag löscht, sieht wieder die gemessene Nacht.
///
/// **Beim Tagschlaf ist es umgekehrt, und das ist kein Widerspruch.** Dort
/// addiert sich der Eintrag zu den gemessenen Phasen (`tagschlaf.js`,
/// Zustand `von-hand`: „Die Summe oben zählt beide Phasen, die gemessene
/// und die eingetragene"). Eine Nacht gibt es je Tag einmal, ein Nickerchen
/// mehrfach — ein eingetragenes Nickerchen ersetzt deshalb keines, es kommt
/// dazu.
///
/// ## Was eine eingetragene Nacht **nicht** verändert
///
/// Verlauf, die beiden Schnitt-Karten und „Sieben Nächte" rechnen weiter
/// über die **gemessenen** Nächte. Ein Eintrag hat keine Phasen; ihn in
/// eine Phasenverteilung einzurechnen hieße, eine zu erfinden — genau die
/// „Zahl ohne Messung", gegen die dieses Ticket geschrieben ist. Dass diese
/// Blöcke sich nicht mitbewegen, sagt der Schirm.
///
/// ## Festgelegte öffentliche API
///
/// ```dart
/// // lib/shell/schlaf_von_hand.dart, reexportiert über schlaf_zustand.dart
///
/// /// Die gemessenen Nächte, über die die eingetragenen gelegt sind.
/// List<SleepNight> naechteMitEintraegen({
///   required List<SleepNight> gemessen,
///   required List<SchlafEintrag> eintraege,
/// });
///
/// /// Der eingetragene Nacht-Eintrag dieses Tages, oder null.
/// SchlafEintrag? nachtEintragZu(DateTime tag, List<SchlafEintrag> eintraege);
///
/// /// Die eingetragenen Nickerchen dieses Tages, nach Beginn sortiert.
/// List<SchlafEintrag> tagschlafEintraegeZu(
///   DateTime tag,
///   List<SchlafEintrag> eintraege,
/// );
///
/// // lib/shell/schlaf_zustand.dart
///
/// class SchlafNacht {
///   /// Der Eintrag, wenn diese Nacht von Hand eingetragen ist.
///   final SchlafEintrag? vonHand;
///   /// Die eingetragenen Nickerchen desselben Tages.
///   final List<SchlafEintrag> napEintraege;
///   /// „23:10–06:15" — aus den Zeiten der Nacht, gemessen oder getippt.
///   String get fensterText;
/// }
///
/// SchlafZustand schlafZustandAus({
///   required Messwert<List<SleepNight>> naechte,
///   required Ziele ziele,
///   required DateTime? gewaehlt,
///   required DateTime jetzt,
///   List<SchlafEintrag> eintraege = const [],
/// });
/// ```
void main() {
  final jetzt = DateTime.utc(2026, 10, 29, 9);
  DateTime tag(int tagImMonat) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, 10, tagImMonat, 12));

  /// Eine gemessene Nacht: ein durchgehender Kernschlafabschnitt.
  SleepNight gemesseneNacht(
    int tagImMonat, {
    int vonStunde = 23,
    int minuten = 420,
    List<SleepSession> naps = const [],
  }) {
    final beginn = BerlinCalendar.startOfDay(
      DateTime.utc(2026, 10, tagImMonat - 1, 12),
    ).add(Duration(hours: vonStunde));
    return SleepNight(
      date: tag(tagImMonat),
      session: SleepSession(
        segments: [
          SleepSegment(
            stage: SleepStage.core,
            start: beginn,
            end: beginn.add(Duration(minutes: minuten)),
          ),
        ],
      ),
      naps: naps,
    );
  }

  SchlafEintrag nachtEintrag(
    int tagImMonat, {
    int schlafMinuten = 425,
    int? beginnMinuten = 23 * 60 + 10,
    int? endeMinuten = 6 * 60 + 15,
  }) => SchlafEintrag(
    tag: BerlinCalendar.dayKey(tag(tagImMonat)),
    art: SchlafEintragArt.nacht,
    lfdNr: 0,
    schlafMinuten: schlafMinuten,
    beginnMinuten: beginnMinuten,
    endeMinuten: endeMinuten,
  );

  SchlafZustand zustandAus({
    required List<SleepNight> gemessen,
    List<SchlafEintrag> eintraege = const [],
    DateTime? gewaehlt,
    Messwert<List<SleepNight>>? messwert,
  }) => schlafZustandAus(
    naechte:
        messwert ??
        Bekannt<List<SleepNight>>(gemessen, stand: jetzt, laeuft: false),
    ziele: Ziele.vorbelegung,
    gewaehlt: gewaehlt,
    jetzt: jetzt,
    eintraege: eintraege,
  );

  SchlafDaten daten(SchlafZustand zustand) =>
      (zustand.daten as Bekannt<SchlafDaten>).wert;

  // ───────────────────────────────────────────────────────────────────────
  // Der Eintrag schlägt die Messung
  // ───────────────────────────────────────────────────────────────────────

  group('Eingetippt schlägt gemessen (SPEC 4.6)', () {
    test('liegt für denselben Aufwachtag beides vor, steht die eingetragene '
        'Nacht oben — und die gemessenen Phasen stehen nicht daneben', () {
      final zustand = zustandAus(
        gemessen: [gemesseneNacht(29)],
        eintraege: [nachtEintrag(29)],
      );

      final nacht = daten(zustand).nacht!;
      expect(nacht.vonHand, isNotNull);
      expect(nacht.vonHand!.schlafMinuten, 425);
      expect(
        nacht.nacht.session.segments,
        isEmpty,
        reason:
            'eine aus gemessener Dauer und eingetippter Zeit '
            'zusammengesetzte Nacht hätte es so nie gegeben',
      );
    });

    test('die Dauer ist die eingetragene, nicht die gemessene', () {
      final zustand = zustandAus(
        gemessen: [gemesseneNacht(29, minuten: 300)],
        eintraege: [nachtEintrag(29, schlafMinuten: 425)],
      );

      expect(daten(zustand).nacht!.kern.asleepMinutes, 425);
    });

    test('und ohne Eintrag bleibt alles, wie es war — die gemessene Nacht mit '
        'ihren Phasen', () {
      final zustand = zustandAus(gemessen: [gemesseneNacht(29)]);

      final nacht = daten(zustand).nacht!;
      expect(nacht.vonHand, isNull);
      expect(nacht.nacht.session.segments, hasLength(1));
      expect(nacht.kern.asleepMinutes, 420);
    });

    test('ein Eintrag für einen anderen Tag lässt diese Nacht in Ruhe', () {
      final zustand = zustandAus(
        gemessen: [gemesseneNacht(29)],
        eintraege: [nachtEintrag(27)],
      );

      expect(daten(zustand).nacht!.vonHand, isNull);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Der Score
  // ───────────────────────────────────────────────────────────────────────

  group('Der Score einer eingetragenen Nacht', () {
    test('mit Zeiten: Dauer und Zubettgehzeit zählen, die Unterbrechungen '
        'entfallen — 80 erreichbare Punkte', () {
      final zustand = zustandAus(
        gemessen: [gemesseneNacht(29)],
        eintraege: [nachtEintrag(29)],
      );

      final score = daten(zustand).nacht!.score;
      expect(score.duration, 44);
      expect(score.bedtime, 27);
      expect(score.interruptions, isNull);
      expect(score.total, 71);
      expect(score.maxTotal, 80);
      expect(score.rating, SleepRating.veryGood);
    });

    test('nur Dauer: auch die Zubettgehzeit entfällt — 50 erreichbare Punkte, '
        'genau was der Satz unter dem Formular ankündigt', () {
      final zustand = zustandAus(
        gemessen: [gemesseneNacht(29)],
        eintraege: [nachtEintrag(29, beginnMinuten: null, endeMinuten: null)],
      );

      final score = daten(zustand).nacht!.score;
      expect(score.bedtime, isNull);
      expect(score.interruptions, isNull);
      expect(score.maxTotal, 50);
    });

    test('die Teilnoten tragen beide Entfallgründe', () {
      final zustand = zustandAus(
        gemessen: [gemesseneNacht(29)],
        eintraege: [nachtEintrag(29, beginnMinuten: null, endeMinuten: null)],
      );

      final teile = daten(zustand).nacht!.teilnoten;
      expect(teile[1].grund, SchlafEntfallGrund.keineEinschlafzeit);
      expect(teile[2].grund, SchlafEntfallGrund.keinePhasendaten);
    });

    test('und er steht auch im Kalenderblatt — der Tag hat einen Score, keinen '
        'leeren Platz', () {
      final zustand = zustandAus(
        gemessen: [gemesseneNacht(29)],
        eintraege: [nachtEintrag(29)],
      );

      expect(daten(zustand).scores[tag(29)]?.maxTotal, 80);
    });

    test('das Zeitfenster kommt aus den eingetippten Uhrzeiten', () {
      final zustand = zustandAus(
        gemessen: [gemesseneNacht(29)],
        eintraege: [nachtEintrag(29)],
      );

      expect(daten(zustand).nacht!.fensterText, '23:10–06:15');
    });

    test('ohne Zeiten steht dort ein Gedankenstrich, keine erfundene Uhr', () {
      final zustand = zustandAus(
        gemessen: [gemesseneNacht(29)],
        eintraege: [nachtEintrag(29, beginnMinuten: null, endeMinuten: null)],
      );

      expect(daten(zustand).nacht!.fensterText, '—');
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Eine Nacht, die es ohne Eintrag gar nicht gäbe
  // ───────────────────────────────────────────────────────────────────────

  group('Ein Tag, den die Uhr nicht kennt', () {
    test('taucht in der Reihe auf und lässt sich anblättern', () {
      final zustand = zustandAus(
        gemessen: [gemesseneNacht(27)],
        eintraege: [nachtEintrag(29)],
      );

      final d = daten(zustand);
      // Oben steht die jüngste Nacht — und das ist die eingetragene.
      expect(d.nacht!.nacht.date, tag(29));
      expect(d.nacht!.vonHand, isNotNull);
      // Und zurück geht es auf den **28.** — den leeren Tag dazwischen.
      //
      // Bis zum 30.10.2026 stand hier `tag(27)`: Geblättert wurde von Nacht
      // zu Nacht, leere Tage wurden übersprungen. Genau das hebt #177 auf
      // (Tims Entscheidung) — der 28. liegt im gelesenen Zeitraum, hat keine
      // Nacht und ist damit ein gültiger Tag, auf dem sich eine nachtragen
      // lässt. Das ist der Fall, für den #131 gebaut wurde.
      expect(d.frueher, tag(28));
      expect(d.spaeter, isNull);
    });

    test('die gewählte Nacht lässt sich auf den Eintrag setzen', () {
      final zustand = zustandAus(
        gemessen: [gemesseneNacht(27)],
        eintraege: [nachtEintrag(29)],
        gewaehlt: tag(29),
      );

      expect(daten(zustand).nacht!.vonHand, isNotNull);
    });

    test('und wenn Apple Health gar nichts hatte, steht trotzdem die '
        'eingetragene Nacht da — das ist der Zustand, in dem man sie '
        'einträgt', () {
      final zustand = zustandAus(
        gemessen: const [],
        eintraege: [nachtEintrag(29)],
        messwert: LeerNachLauf<List<SleepNight>>(gelaufen: jetzt),
      );

      expect(zustand.daten, isA<Bekannt<SchlafDaten>>());
      expect(daten(zustand).nacht!.vonHand, isNotNull);
    });

    test('ohne einen einzigen Eintrag bleibt der leere Lauf aber leer — kein '
        'Bekannt ohne Inhalt', () {
      final zustand = zustandAus(
        gemessen: const [],
        messwert: LeerNachLauf<List<SleepNight>>(gelaufen: jetzt),
      );

      expect(zustand.daten, isA<LeerNachLauf<SchlafDaten>>());
    });

    test('und ein gescheiterter Lauf bleibt ein gescheiterter Lauf', () {
      final zustand = zustandAus(
        gemessen: const [],
        eintraege: [nachtEintrag(29)],
        messwert: Fehlgeschlagen<List<SleepNight>>(
          fehler: Exception('Kanal nicht erreichbar'),
          gelaufen: jetzt,
        ),
      );

      expect(
        zustand.daten,
        isA<Fehlgeschlagen<SchlafDaten>>(),
        reason:
            'ein Fehler ist keine Aussage über die Datenlage — ihn hinter '
            'einer eingetragenen Nacht verschwinden zu lassen wäre eine',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Tagschlaf
  // ───────────────────────────────────────────────────────────────────────

  group('Ein eingetragenes Nickerchen kommt dazu, statt zu ersetzen', () {
    SchlafEintrag napEintrag(
      int tagImMonat, {
      int schlafMinuten = 45,
      int? beginnMinuten = 18 * 60 + 10,
      int? endeMinuten = 18 * 60 + 55,
      int lfdNr = 0,
    }) => SchlafEintrag(
      tag: BerlinCalendar.dayKey(tag(tagImMonat)),
      art: SchlafEintragArt.tagschlaf,
      lfdNr: lfdNr,
      schlafMinuten: schlafMinuten,
      beginnMinuten: beginnMinuten,
      endeMinuten: endeMinuten,
    );

    SleepSession gemessenesNickerchen(int tagImMonat, {int minuten = 35}) {
      final beginn = BerlinCalendar.startOfDay(
        DateTime.utc(2026, 10, tagImMonat, 12),
      ).add(const Duration(hours: 13, minutes: 40));
      return SleepSession(
        segments: [
          SleepSegment(
            stage: SleepStage.core,
            start: beginn,
            end: beginn.add(Duration(minutes: minuten)),
          ),
        ],
      );
    }

    test('die Tagschlaf-Zeile zählt beide Phasen', () {
      final zustand = zustandAus(
        gemessen: [
          gemesseneNacht(29, naps: [gemessenesNickerchen(29)]),
        ],
        eintraege: [napEintrag(29)],
      );

      final nacht = daten(zustand).nacht!;
      expect(nacht.napEintraege, hasLength(1));
      expect(nacht.tagschlafMinuten, 35 + 45);
      expect(nacht.tagschlafAnzahl, 2);
    });

    test('auch wenn die Uhr gar keines erkannt hat', () {
      final zustand = zustandAus(
        gemessen: [gemesseneNacht(29)],
        eintraege: [napEintrag(29)],
      );

      final nacht = daten(zustand).nacht!;
      expect(nacht.tagschlafMinuten, 45);
      expect(nacht.tagschlafAnzahl, 1);
    });

    test('und ein eingetragenes Nickerchen überlebt den Nacht-Eintrag '
        'desselben Tages — die beiden beantworten verschiedene Fragen', () {
      final zustand = zustandAus(
        gemessen: [
          gemesseneNacht(29, naps: [gemessenesNickerchen(29)]),
        ],
        eintraege: [nachtEintrag(29), napEintrag(29)],
      );

      final nacht = daten(zustand).nacht!;
      expect(nacht.vonHand, isNotNull);
      expect(nacht.tagschlafMinuten, 35 + 45);
    });

    test('mehrere eingetragene Nickerchen stehen nach Beginn sortiert', () {
      final zustand = zustandAus(
        gemessen: [gemesseneNacht(29)],
        eintraege: [
          napEintrag(
            29,
            lfdNr: 0,
            beginnMinuten: 18 * 60,
            endeMinuten: 18 * 60 + 30,
          ),
          napEintrag(
            29,
            lfdNr: 1,
            beginnMinuten: 13 * 60,
            endeMinuten: 13 * 60 + 40,
          ),
        ],
      );

      expect(daten(zustand).nacht!.napEintraege.map((e) => e.beginnMinuten), [
        13 * 60,
        18 * 60,
      ]);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Die reinen Funktionen
  // ───────────────────────────────────────────────────────────────────────

  group('naechteMitEintraegen', () {
    test('sortiert aufsteigend nach Tag, egal wie es hineinging', () {
      final gemischt = naechteMitEintraegen(
        gemessen: [gemesseneNacht(29), gemesseneNacht(27)],
        eintraege: [nachtEintrag(28)],
      );

      expect(gemischt.map((n) => n.date), [tag(27), tag(28), tag(29)]);
    });

    test('ohne Einträge gibt sie die Messung unverändert zurück', () {
      final gemessen = [gemesseneNacht(27), gemesseneNacht(29)];

      expect(
        naechteMitEintraegen(gemessen: gemessen, eintraege: const []),
        gemessen,
      );
    });

    test('ein Tagschlaf-Eintrag allein macht noch keine Nacht', () {
      final gemischt = naechteMitEintraegen(
        gemessen: const [],
        eintraege: [
          SchlafEintrag(
            tag: BerlinCalendar.dayKey(tag(29)),
            art: SchlafEintragArt.tagschlaf,
            lfdNr: 0,
            schlafMinuten: 35,
          ),
        ],
      );

      expect(gemischt, isEmpty);
    });
  });
}
