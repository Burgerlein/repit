import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/gym_repository.dart';
import 'package:repit/data/umfaenge_repository.dart';
import 'package:repit/uebernahme/trainingsexport_uebernahme.dart';

import '../uebernahme/export_fixtur.dart';

/// Tests für die **Übernahme der Umfänge** aus der Exportdatei der alten App
/// (#498, unter #59 und #88): `UmfaengeRepository.uebernimm` und der Weg
/// *Datei rein, Bericht raus* über `uebernimmTrainingsexport`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden — keine Zeile,
/// kein Erwartungswert, kein Testname. Hält der Implementierende einen Fall
/// für falsch, **meldet** er ihn, statt ihn passend zu machen.
///
/// Geschrieben aus dem Ticket #498 und aus
/// `docs/superpowers/specs/2026-11-11-gym-uebernahme-design.md` (Abschnitte
/// 5, 9, 10 und 15 — der Umfänge-Teil ist ein **Anbau** an diese Spec),
/// **ohne** den späteren Code gesehen zu haben. Die Rechnungen darunter
/// prüfen `trainings_export_umfaenge_test.dart` und `umfangs_import_test.dart`
/// im Kern; die Gym-Seite prüft `trainingsexport_uebernahme_test.dart`.
///
/// ## Der Kern der Sache
///
/// Geschrieben wird mit **`quelle = 'import'`**. Der Primärschlüssel der
/// Tabelle ist **Tag + Maß + Quelle** (`tables.dart`), und `UmfangsMerge`
/// führt beim **Lesen** zusammen: getippt schlägt importiert, maßweise.
/// Beides zusammen ergibt die Zusage, auf die Tim sich verlässt: **Ein von
/// Hand eingetragener Wert wird vom Import nie überschrieben** — auch dann
/// nicht, wenn die Importdatei später erzeugt wurde. Die Uhrzeit entscheidet
/// hier nichts; der Export trägt die Uhrzeit des Exports, und die sagt
/// nichts darüber, wann gemessen wurde.
///
/// ## Festgelegte API — Entscheidungen des Test-Agenten, **nicht von Tim**
///
/// ```dart
/// // app/lib/data/umfaenge_repository.dart
/// /// Schreibt übernommene Messungen — **nur dazu, nie ersetzen, nie
/// /// löschen**, immer mit `quelle = 'import'`. Liest, plant
/// /// (`UmfangsImport.plan`) und schreibt in **einer** Transaktion.
/// Future<UmfaengeUebernahme> UmfaengeRepository.uebernimm(
///     List<Umfangsmessung> messungen);
///
/// final class UmfaengeUebernahme {
///   final List<Umfangsmessung> geschrieben;      // neu, tagweise, aufsteigend
///   final List<Umfangsmessung> schonVorhanden;   // als Import schon da
/// }
///
/// // app/lib/uebernahme/trainingsexport_uebernahme.dart
/// Future<TrainingsexportErgebnis> uebernimmTrainingsexport(
///   GymRepository ablage,
///   Uint8List bytes, {
///   UmfaengeRepository? umfaenge,      // fehlt sie, wird nichts geschrieben
/// });
///
/// // zusätzlich in TrainingsexportUebernommen:
/// final List<Umfangsmessung> umfaengeGeschrieben;
/// final List<Umfangsmessung> umfaengeSchonVorhanden;
/// final List<ExportMeasureSkip> umfaengeNichtLesbar;
/// final List<String> unbekannteMasse;    // sortiert, ohne Dubletten
/// int get umfaengeNeu;        // Zahl der neu geschriebenen Einzelwerte
/// int get umfaengeSchonDa;    // Zahl der Einzelwerte, die schon dastanden
/// int get umfaengeTage;       // Zahl der Tage, an denen etwas dazukam
/// ```
///
/// **Warum `umfaenge` benannt und nicht verlangt:** Die bestehende
/// Testdatei `trainingsexport_uebernahme_test.dart` ruft die Funktion
/// fünfundzwanzigmal mit zwei Argumenten. Ein Pflichtparameter bräche sie,
/// und ein Test, den der neue Schritt rot macht, wäre teurer als die eine
/// Stelle, die hier geprüft wird: Dass der echte Weg die Ablage wirklich
/// mitgibt, nagelt `test/uebernahme/uebernahme_umfaenge_test.dart` fest.
/// **Gelesen** werden die Umfänge in jedem Fall — `ExportRead` trägt sie,
/// und `circumferences` fällt aus `unread` heraus.
///
/// Alle Zahlen, Tage und Namen sind **erfunden** und liegen im Jahr 2099 —
/// keine echten Gesundheitsdaten (`CLAUDE.md`). Im Januar gilt Berliner
/// Winterzeit (UTC+1).
void main() {
  /* ---- Hülle --------------------------------------------------------- */

  /// Wann die App gelaufen ist, für `eingetragen_am`.
  final jetzt = DateTime.utc(2099, 2, 1, 18, 5);

  /// Früher als [jetzt] und früher als das `generated` der Datei.
  final frueher = DateTime.utc(2099, 1, 2, 7, 30);

  late AppCache db;
  late GymRepository gym;
  late UmfaengeRepository umfaenge;

  setUp(() {
    db = AppCache(NativeDatabase.memory());
    gym = GymRepository(db);
    umfaenge = UmfaengeRepository(db, uhr: () => jetzt);
  });
  tearDown(() => db.close());

  /// Alle Zeilen roh — was hier steht, ist das, was wirklich in der Datei
  /// liegt.
  Future<List<Map<String, Object?>>> rohZeilen() async => [
    for (final zeile
        in await db
            .customSelect(
              'SELECT * FROM umfaenge ORDER BY tag, mass, quelle;',
            )
            .get())
      zeile.data,
  ];

  Umfangsmessung messung(DateTime wann, Map<Umfang, double> werte) =>
      Umfangsmessung(zeitpunkt: wann, werte: werte);

  /// Ein Umfangs-Eintrag, so wie Swift ihn in die Datei schreibt.
  Map<String, Object?> rohMessung(String datum, Map<String, Object?> werte) => {
    'date': datum,
    'values': werte,
  };

  /// Eine Datei mit Umfängen (und wahlweise Trainings) als Bytes.
  Uint8List dateiMit({
    List<Object?> messungen = const [],
    List<Object?> sitzungen = const [],
  }) => alsBytes(
    exportDatei(sitzungen: sitzungen, uebrige: {'circumferences': messungen}),
  );

  TrainingsexportUebernommen uebernommen(TrainingsexportErgebnis e) {
    expect(e, isA<TrainingsexportUebernommen>(), reason: '$e');
    return e as TrainingsexportUebernommen;
  }

  // ────────────────────────────────────────────────────────────────────
  // Die Ablage
  // ────────────────────────────────────────────────────────────────────

  group('`uebernimm` schreibt mit quelle = import', () {
    test('Je Maß eine Zeile, mit Tag, Wert und Quelle', () async {
      await umfaenge.uebernimm([
        messung(DateTime.utc(2099, 1, 14, 9), {
          Umfang.taille: 81.0,
          Umfang.brust: 102.4,
        }),
      ]);

      final zeilen = await rohZeilen();
      expect(zeilen, hasLength(2));
      for (final zeile in zeilen) {
        expect(zeile['tag'], '2099-01-14');
        expect(
          zeile['quelle'],
          quelleImport,
          reason: 'Nur mit `import` im Schlüssel kann ein getippter Wert '
              'daneben stehen bleiben',
        );
      }
      expect(
        {for (final z in zeilen) z['mass']: z['zentimeter']},
        {
          Umfang.taille.schluessel: 81.0,
          Umfang.brust.schluessel: 102.4,
        },
      );
    });

    test('`eingetragen_am` kommt aus der Uhr — nichts wird erfunden', () async {
      await umfaenge.uebernimm([
        messung(DateTime.utc(2099, 1, 14, 9), {Umfang.taille: 81.0}),
      ]);

      final roh = (await rohZeilen()).single['eingetragen_am'];
      expect(
        DateTime.parse(roh! as String).toUtc(),
        jetzt,
        reason: 'Der Zeitpunkt der Übernahme, nicht der Messzeitpunkt der '
            'Datei und kein erfundener Wert',
      );
    });

    test('Der Tag ist der Berliner Tag, nicht der UTC-Tag', () async {
      await umfaenge.uebernimm([
        messung(DateTime.utc(2099, 1, 14, 23, 30), {Umfang.taille: 81.0}),
      ]);

      expect(
        (await rohZeilen()).single['tag'],
        '2099-01-15',
        reason: '23:30 UTC im Januar ist 00:30 Berliner Zeit des Folgetags',
      );
    });

    test('Die Rückgabe nennt, was geschrieben wurde', () async {
      final ergebnis = await umfaenge.uebernimm([
        messung(DateTime.utc(2099, 1, 14, 9), {Umfang.taille: 81.0}),
        messung(DateTime.utc(2099, 1, 21, 9), {Umfang.taille: 80.5}),
      ]);

      expect(ergebnis.geschrieben, hasLength(2));
      expect(ergebnis.schonVorhanden, isEmpty);
      expect(
        [for (final m in ergebnis.geschrieben) BerlinCalendar.dayKey(m.zeitpunkt)],
        ['2099-01-14', '2099-01-21'],
      );
    });

    test('Eine leere Liste schreibt nichts und wirft nicht', () async {
      final ergebnis = await umfaenge.uebernimm(const []);

      expect(ergebnis.geschrieben, isEmpty);
      expect(ergebnis.schonVorhanden, isEmpty);
      expect(await rohZeilen(), isEmpty);
    });

    test('Eine Messung ohne Werte legt keine Zeile an', () async {
      await umfaenge.uebernimm([messung(DateTime.utc(2099, 1, 14, 9), const {})]);

      expect(await rohZeilen(), isEmpty);
    });
  });

  group('Zweimal übernehmen verdoppelt nichts', () {
    test('Dieselbe Liste zweimal: derselbe Stand, nichts Neues', () async {
      final ausDerDatei = [
        messung(DateTime.utc(2099, 1, 14, 9), {
          Umfang.taille: 81.0,
          Umfang.brust: 102.4,
        }),
      ];

      await umfaenge.uebernimm(ausDerDatei);
      final nachErstem = await rohZeilen();
      final zweiter = await umfaenge.uebernimm(ausDerDatei);

      expect(await rohZeilen(), nachErstem);
      expect(zweiter.geschrieben, isEmpty);
      expect(zweiter.schonVorhanden.single.werte, hasLength(2));
    });

    test('Ein geänderter Wert zieht den Stand nicht zurück', () async {
      await umfaenge.uebernimm([
        messung(DateTime.utc(2099, 1, 14, 9), {Umfang.taille: 81.0}),
      ]);

      await umfaenge.uebernimm([
        messung(DateTime.utc(2099, 1, 14, 9), {Umfang.taille: 75.0}),
      ]);

      expect((await rohZeilen()).single['zentimeter'], 81.0);
    });

    test('Eine gewachsene Datei bringt genau die neuen Maße', () async {
      await umfaenge.uebernimm([
        messung(DateTime.utc(2099, 1, 14, 9), {Umfang.taille: 81.0}),
      ]);

      final zweiter = await umfaenge.uebernimm([
        messung(DateTime.utc(2099, 1, 14, 9), {
          Umfang.taille: 81.0,
          Umfang.hals: 39.0,
        }),
        messung(DateTime.utc(2099, 1, 21, 9), {Umfang.taille: 80.5}),
      ]);

      expect(zweiter.geschrieben, [
        messung(DateTime.utc(2099, 1, 13, 23), {Umfang.hals: 39.0}),
        messung(DateTime.utc(2099, 1, 20, 23), {Umfang.taille: 80.5}),
      ]);
      expect(await rohZeilen(), hasLength(3));
    });
  });

  group('Ein von Hand eingetragener Wert wird nie überschrieben', () {
    test('Der getippte Wert steht nach dem Import weiter da', () async {
      await UmfaengeRepository(
        db,
        uhr: () => frueher,
      ).schreibeGetippt(tag: '2099-01-14', werte: {Umfang.taille: 79.0});

      await umfaenge.uebernimm([
        messung(DateTime.utc(2099, 1, 14, 9), {Umfang.taille: 83.0}),
      ]);

      final gelesen = await umfaenge.messungAm('2099-01-14');
      expect(
        gelesen!.werte[Umfang.taille],
        79.0,
        reason: 'Getippt schlägt importiert (UmfangsMerge), maßweise',
      );
    });

    test('Auch dann nicht, wenn die Importdatei später erzeugt wurde', () async {
      await UmfaengeRepository(
        db,
        uhr: () => frueher,
      ).schreibeGetippt(tag: '2099-01-14', werte: {Umfang.taille: 79.0});

      final e = uebernommen(
        await uebernimmTrainingsexport(
          gym,
          dateiMit(
            messungen: [
              rohMessung(zeit(14), {'waist': 83.0}),
            ],
          ),
          umfaenge: umfaenge,
        ),
      );

      expect(
        e.erzeugtAm.isAfter(frueher),
        isTrue,
        reason: 'Die Datei ist jünger als der getippte Wert',
      );
      expect((await umfaenge.messungAm('2099-01-14'))!.werte[Umfang.taille], 79.0);
    });

    test('Beide Zeilen liegen nebeneinander — die Entscheidung fällt beim '
        'Lesen, nicht beim Schreiben', () async {
      await UmfaengeRepository(
        db,
        uhr: () => frueher,
      ).schreibeGetippt(tag: '2099-01-14', werte: {Umfang.taille: 79.0});

      await umfaenge.uebernimm([
        messung(DateTime.utc(2099, 1, 14, 9), {Umfang.taille: 83.0}),
      ]);

      final zeilen = await rohZeilen();
      expect(zeilen, hasLength(2));
      expect(
        {for (final z in zeilen) z['quelle']: z['zentimeter']},
        {quelleGetippt: 79.0, quelleImport: 83.0},
      );
    });

    test('Ein Maß, das nur der Import kennt, kommt am selben Tag dazu', () async {
      await UmfaengeRepository(
        db,
        uhr: () => frueher,
      ).schreibeGetippt(tag: '2099-01-14', werte: {Umfang.taille: 79.0});

      await umfaenge.uebernimm([
        messung(DateTime.utc(2099, 1, 14, 9), {
          Umfang.taille: 83.0,
          Umfang.brust: 102.4,
        }),
      ]);

      expect((await umfaenge.messungAm('2099-01-14'))!.werte, {
        Umfang.taille: 79.0,
        Umfang.brust: 102.4,
      });
    });

    test('Ein getippter Wert hindert den Import nicht daran, seine eigene '
        'Zeile zu schreiben', () async {
      await UmfaengeRepository(
        db,
        uhr: () => frueher,
      ).schreibeGetippt(tag: '2099-01-14', werte: {Umfang.taille: 79.0});

      final ergebnis = await umfaenge.uebernimm([
        messung(DateTime.utc(2099, 1, 14, 9), {Umfang.taille: 83.0}),
      ]);

      expect(ergebnis.geschrieben.single.werte, {Umfang.taille: 83.0});
      expect(ergebnis.schonVorhanden, isEmpty);
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // Datei rein, Bericht raus
  // ────────────────────────────────────────────────────────────────────

  group('Die Umfänge der Datei landen in der Ablage', () {
    test('Eine Messung mit allen Maßen kommt vollständig an', () async {
      final werte = <String, Object?>{};
      final erwartet = <Umfang, double>{};
      for (var i = 0; i < Umfang.values.length; i++) {
        final mass = Umfang.values[i];
        final wert = 20.0 + i * 2;
        werte[mass.schluessel] = wert;
        erwartet[mass] = wert;
      }

      final e = uebernommen(
        await uebernimmTrainingsexport(
          gym,
          dateiMit(messungen: [rohMessung(zeit(14), werte)]),
          umfaenge: umfaenge,
        ),
      );

      expect(e.umfaengeNeu, Umfang.values.length);
      expect(e.umfaengeTage, 1);
      expect((await umfaenge.messungAm('2099-01-14'))!.werte, erwartet);
    });

    test('Trainings und Umfänge in einem Lauf — der Bericht nennt beides', () async {
      final e = uebernommen(
        await uebernimmTrainingsexport(
          gym,
          dateiMit(
            sitzungen: [
              rohSitzung(id: 'S-A', datum: zeit(10), workout: 'A'),
              rohSitzung(id: 'S-B', datum: zeit(12), workout: 'B'),
            ],
            messungen: [
              rohMessung(zeit(10), {'waist': 81.0, 'chest': 102.4}),
              rohMessung(zeit(17), {'waist': 80.5}),
            ],
          ),
          umfaenge: umfaenge,
        ),
      );

      expect(e.neu, 2, reason: 'Die Trainings zählen weiter für sich');
      expect(e.umfaengeNeu, 3);
      expect(e.umfaengeTage, 2);
      expect(e.umfaengeSchonDa, 0);
      expect(e.umfaengeNichtLesbar, isEmpty);
      expect(e.unbekannteMasse, isEmpty);
      expect(await rohZeilen(), hasLength(3));
    });

    test('Der Bericht trägt die geschriebenen Messungen, nicht nur Zahlen', () async {
      final e = uebernommen(
        await uebernimmTrainingsexport(
          gym,
          dateiMit(
            messungen: [
              rohMessung(zeit(14), {'thigh': 61.0, 'calf': 39.0}),
            ],
          ),
          umfaenge: umfaenge,
        ),
      );

      expect(e.umfaengeGeschrieben, [
        Umfangsmessung(
          zeitpunkt: DateTime.utc(2099, 1, 13, 23),
          werte: {Umfang.oberschenkelRechts: 61.0, Umfang.wadeRechts: 39.0},
        ),
      ]);
    });

    test('Eine Datei ohne Umfänge: keine Zeile, keine Zahl, kein Hinweis auf '
        'Ungelesenes', () async {
      final e = uebernommen(
        await uebernimmTrainingsexport(
          gym,
          alsBytes(
            exportDatei(
              sitzungen: [rohSitzung(id: 'S-A', datum: zeit(10), workout: 'A')],
            ),
          ),
          umfaenge: umfaenge,
        ),
      );

      expect(e.umfaengeNeu, 0);
      expect(e.umfaengeGeschrieben, isEmpty);
      expect(await rohZeilen(), isEmpty);
      expect(e.ungelesen.containsKey('circumferences'), isFalse);
    });

    test('Gelesene Umfänge stehen nicht unter „ungelesen"', () async {
      final e = uebernommen(
        await uebernimmTrainingsexport(
          gym,
          dateiMit(
            messungen: [
              rohMessung(zeit(14), {'waist': 81.0}),
            ],
          ),
          umfaenge: umfaenge,
        ),
      );

      expect(e.umfaengeNeu, 1);
      expect(
        e.ungelesen.containsKey('circumferences'),
        isFalse,
        reason: 'Ein Bericht, der Gelesenes als ungelesen meldet, ist falsch',
      );
    });

    test('Zweimal dieselbe Datei verdoppelt nichts', () async {
      final bytes = dateiMit(
        sitzungen: [rohSitzung(id: 'S-A', datum: zeit(10), workout: 'A')],
        messungen: [
          rohMessung(zeit(14), {'waist': 81.0, 'chest': 102.4}),
        ],
      );

      final erster = uebernommen(
        await uebernimmTrainingsexport(gym, bytes, umfaenge: umfaenge),
      );
      final stand = await rohZeilen();
      final zweiter = uebernommen(
        await uebernimmTrainingsexport(gym, bytes, umfaenge: umfaenge),
      );

      expect(erster.umfaengeNeu, 2);
      expect(zweiter.umfaengeNeu, 0);
      expect(zweiter.umfaengeSchonDa, 2);
      expect(zweiter.umfaengeTage, 0);
      expect(await rohZeilen(), stand);
    });

    test('Der Berliner Tag entscheidet, nicht der UTC-Tag', () async {
      await uebernimmTrainingsexport(
        gym,
        dateiMit(
          messungen: [
            rohMessung(zeit(14, 23, 30), {'waist': 81.0}),
          ],
        ),
        umfaenge: umfaenge,
      );

      expect((await rohZeilen()).single['tag'], '2099-01-15');
    });
  });

  group('Was nicht taugt, wird benannt und nicht geraten', () {
    test('Ein unbekannter Schlüssel kippt die Datei nicht', () async {
      final e = uebernommen(
        await uebernimmTrainingsexport(
          gym,
          dateiMit(
            messungen: [
              rohMessung(zeit(14), {'waist': 81.0, 'ellbogen': 29.0}),
            ],
          ),
          umfaenge: umfaenge,
        ),
      );

      expect(e.unbekannteMasse, ['ellbogen']);
      expect(e.umfaengeNeu, 1);
      expect((await rohZeilen()).single['mass'], Umfang.taille.schluessel);
    });

    test('Ein unplausibler Wert wird übersprungen, der Rest geschrieben', () async {
      final e = uebernommen(
        await uebernimmTrainingsexport(
          gym,
          dateiMit(
            messungen: [
              rohMessung(zeit(14), {'waist': 810.0, 'chest': 102.4}),
            ],
          ),
          umfaenge: umfaenge,
        ),
      );

      expect(e.umfaengeNichtLesbar, hasLength(1));
      expect(e.umfaengeNichtLesbar.single.measure, 'waist');
      expect(
        e.umfaengeNichtLesbar.single.reason,
        ExportMeasureSkipReason.implausible,
      );
      expect(e.umfaengeNeu, 1);
      expect((await rohZeilen()).single['mass'], Umfang.brust.schluessel);
    });

    test('Ein Wert, der keine Zahl ist, wird nicht umgerechnet', () async {
      final e = uebernommen(
        await uebernimmTrainingsexport(
          gym,
          dateiMit(
            messungen: [
              rohMessung(zeit(14), {'waist': '81,0'}),
            ],
          ),
          umfaenge: umfaenge,
        ),
      );

      expect(
        e.umfaengeNichtLesbar.single.reason,
        ExportMeasureSkipReason.notANumber,
      );
      expect(await rohZeilen(), isEmpty);
    });

    test('Ein kaputter Eintrag nimmt den übrigen nichts weg', () async {
      final e = uebernommen(
        await uebernimmTrainingsexport(
          gym,
          dateiMit(
            messungen: [
              {
                'values': {'waist': 81.0},
              },
              rohMessung(zeit(21), {'waist': 80.5}),
            ],
          ),
          umfaenge: umfaenge,
        ),
      );

      expect(e.umfaengeNichtLesbar, hasLength(1));
      expect(e.umfaengeNeu, 1);
      expect((await rohZeilen()).single['tag'], '2099-01-21');
    });
  });

  group('Eine abgelehnte Datei schreibt nichts — auch keine Umfänge', () {
    Future<void> nichtsGeschrieben() async {
      expect(await rohZeilen(), isEmpty);
      expect(await gym.sitzungen(), isEmpty);
    }

    test('Fassung 1 wird abgelehnt', () async {
      final e = await uebernimmTrainingsexport(
        gym,
        alsBytes(fassungEins()),
        umfaenge: umfaenge,
      );

      expect(e, isA<TrainingsexportAbgelehnt>());
      await nichtsGeschrieben();
    });

    test('Eine Datei, die kein JSON ist, wird abgelehnt', () async {
      final e = await uebernimmTrainingsexport(
        gym,
        Uint8List.fromList([0x7b, 0x7b, 0x7b]),
        umfaenge: umfaenge,
      );

      expect(e, isA<TrainingsexportAbgelehnt>());
      await nichtsGeschrieben();
    });

    test('Eine fremde Datei mit Umfängen wird abgelehnt, bevor etwas '
        'geschrieben wird', () async {
      final e = await uebernimmTrainingsexport(
        gym,
        alsBytes(
          exportDatei(
            format: 'tagebuch',
            uebrige: {
              'circumferences': [
                rohMessung(zeit(14), {'waist': 81.0}),
              ],
            },
          ),
        ),
        umfaenge: umfaenge,
      );

      expect(e, isA<TrainingsexportAbgelehnt>());
      await nichtsGeschrieben();
    });

    test('Eine abgelehnte Datei lässt vorhandene Umfänge unberührt', () async {
      await UmfaengeRepository(
        db,
        uhr: () => frueher,
      ).schreibeGetippt(tag: '2099-01-14', werte: {Umfang.taille: 79.0});
      final vorher = await rohZeilen();

      await uebernimmTrainingsexport(
        gym,
        alsBytes(fassungEins()),
        umfaenge: umfaenge,
      );

      expect(await rohZeilen(), vorher);
    });
  });

  group('Ohne Umfänge-Ablage wird nichts geschrieben', () {
    test('Der Lauf geht durch, die Trainings kommen an, die Umfänge nicht', () async {
      final e = uebernommen(
        await uebernimmTrainingsexport(
          gym,
          dateiMit(
            sitzungen: [rohSitzung(id: 'S-A', datum: zeit(10), workout: 'A')],
            messungen: [
              rohMessung(zeit(14), {'waist': 81.0}),
            ],
          ),
        ),
      );

      expect(e.neu, 1);
      expect(e.umfaengeNeu, 0);
      expect(e.umfaengeGeschrieben, isEmpty);
      expect(await rohZeilen(), isEmpty);
    });
  });
}
