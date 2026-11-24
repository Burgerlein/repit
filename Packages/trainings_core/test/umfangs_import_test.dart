import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `UmfangsImport.plan` — **die eine Stelle, an der entschieden
/// wird, welche übernommenen Umfänge geschrieben werden dürfen** (#498,
/// unter #59 und #88).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Geschrieben aus
/// dem Ticket #498 und aus
/// `docs/superpowers/specs/2026-11-11-gym-uebernahme-design.md`
/// (Abschnitte 3, 4 und 15) — **ohne** den späteren Code gesehen zu haben.
///
/// ## Worum es geht
///
/// Das Gegenstück zu `GymSessionImport.plan`, nur eine Ebene feiner: Bei den
/// Trainings ist die Sitzung die Einheit, bei den Umfängen der **einzelne
/// Wert**. Eine Messung trägt nur die Maße, die an dem Tag wirklich gemessen
/// wurden — wer abends die Taille nachträgt, hat an diesem Tag eine Messung
/// mit einem Maß. Zwei Quellen können denselben Tag mit verschiedenen Maßen
/// füllen, und keine darf die andere wegnehmen.
///
/// Deshalb gilt hier dieselbe Regel wie dort, **maßweise**: *Die Übernahme
/// schreibt nur dazu. Was schon dasteht, bleibt* — auch dann, wenn die Datei
/// für dasselbe Maß desselben Tages eine andere Zahl trägt. Ohne diese Regel
/// zöge ein zweiter Lauf einer alten Datei korrigierte Werte wieder zurück.
///
/// ## Festgelegte API — Entscheidungen des Test-Agenten, **nicht von Tim**
///
/// ```dart
/// // Packages/trainings_core/lib/src/umfangs_import.dart  (exportieren!)
/// abstract final class UmfangsImport {
///   static UmfangsImportPlan plan({
///     required List<Umfangsmessung> existing,   // was als Import schon dasteht
///     required List<Umfangsmessung> incoming,   // was die Datei trägt
///   });
/// }
///
/// final class UmfangsImportPlan {
///   final List<Umfangsmessung> toWrite;         // je Tag nur die neuen Maße
///   final List<Umfangsmessung> alreadyPresent;  // je Tag die Maße, die schon dastanden
/// }
/// ```
///
/// - **Beide Listen sind tagweise gefaltet** und stehen **aufsteigend nach
///   Berliner Tag**; der `zeitpunkt` ist der **Berliner Tagesbeginn**, genau
///   wie bei [UmfangsMerge.messungen]. Die Ablage kennt nur den Tag, nicht
///   die Uhrzeit — eine Uhrzeit im Plan behauptete eine Genauigkeit, die
///   danach niemand mehr hat.
/// - **Ein Tag ohne neue Maße steht nicht in `toWrite`**, auch nicht leer.
/// - **Innerhalb von `incoming` gewinnt der spätere Eintrag der Liste** je
///   Maß — dieselbe Regel, nach der [UmfangsMerge.messungen] faltet. Der
///   Leser legt die Reihenfolge fest (Dashboard-Import zuerst, dann die
///   eigenen Messungen der Altapp).
/// - **`existing` sind die Zeilen der Quelle `import`**, nicht die
///   getippten. Ein von Hand eingetragener Wert steht in der Ablage daneben
///   und gewinnt erst beim Lesen (`UmfangsMerge`); er hindert die Übernahme
///   nicht daran, ihre eigene Zeile zu schreiben.
///
/// Alle Zahlen und Zeitpunkte sind **erfunden** und liegen im Jahr 2099 —
/// keine echten Gesundheitsdaten (`CLAUDE.md`). Die Berliner Tagesgrenzen
/// sind von Hand ausgerechnet, nicht über [BerlinCalendar] erzeugt: Im
/// Januar gilt Winterzeit (UTC+1), im Juli Sommerzeit (UTC+2).
void main() {
  /* ---- Zeitpunkte, von Hand gerechnet -------------------------------- */

  /// 14.01.2099, 10:00 Berliner Zeit.
  final vormittags14 = DateTime.utc(2099, 1, 14, 9);

  /// 14.01.2099, 20:00 Berliner Zeit.
  final abends14 = DateTime.utc(2099, 1, 14, 19);

  /// Berliner Tagesbeginn des 14.01.2099.
  final beginn14 = DateTime.utc(2099, 1, 13, 23);

  /// 00:30 Berliner Zeit am 15.01. — in UTC noch der 14.
  final nachts15 = DateTime.utc(2099, 1, 14, 23, 30);

  /// Berliner Tagesbeginn des 15.01.2099.
  final beginn15 = DateTime.utc(2099, 1, 14, 23);

  /// 21.01.2099, 10:00 Berliner Zeit.
  final vormittags21 = DateTime.utc(2099, 1, 21, 9);

  /// Berliner Tagesbeginn des 21.01.2099.
  final beginn21 = DateTime.utc(2099, 1, 20, 23);

  Umfangsmessung messung(DateTime wann, Map<Umfang, double> werte) =>
      Umfangsmessung(zeitpunkt: wann, werte: werte);

  List<DateTime> tage(List<Umfangsmessung> messungen) =>
      [for (final m in messungen) m.zeitpunkt];

  /* ---- Nichts da ----------------------------------------------------- */

  group('plan: nichts da, alles darf geschrieben werden', () {
    test('Leere Ablage: alles wird geschrieben, nichts steht schon da', () {
      final plan = UmfangsImport.plan(
        existing: const [],
        incoming: [
          messung(vormittags14, {Umfang.taille: 81.0, Umfang.brust: 102.0}),
        ],
      );

      expect(plan.toWrite, [
        messung(beginn14, {Umfang.taille: 81.0, Umfang.brust: 102.0}),
      ]);
      expect(plan.alreadyPresent, isEmpty);
    });

    test('Nichts in der Datei: nichts zu tun, kein Fehler', () {
      final plan = UmfangsImport.plan(
        existing: [
          messung(beginn14, {Umfang.taille: 81.0}),
        ],
        incoming: const [],
      );

      expect(plan.toWrite, isEmpty);
      expect(plan.alreadyPresent, isEmpty);
    });

    test('Beide leer: beide Listen leer', () {
      final plan = UmfangsImport.plan(existing: const [], incoming: const []);

      expect(plan.toWrite, isEmpty);
      expect(plan.alreadyPresent, isEmpty);
    });

    test('Eine Messung ohne Werte erzeugt keinen Tag', () {
      final plan = UmfangsImport.plan(
        existing: const [],
        incoming: [messung(vormittags14, const {})],
      );

      expect(plan.toWrite, isEmpty);
      expect(plan.alreadyPresent, isEmpty);
    });
  });

  /* ---- Der Tagesbeginn und die Reihenfolge --------------------------- */

  group('Der Plan steht auf Berliner Tagen, aufsteigend', () {
    test('Der Zeitpunkt wird auf den Berliner Tagesbeginn gesetzt', () {
      final plan = UmfangsImport.plan(
        existing: const [],
        incoming: [
          messung(abends14, {Umfang.taille: 81.0}),
        ],
      );

      expect(tage(plan.toWrite), [beginn14]);
    });

    test('Nach Mitternacht Berliner Zeit ist es der Folgetag', () {
      final plan = UmfangsImport.plan(
        existing: const [],
        incoming: [
          messung(nachts15, {Umfang.taille: 81.0}),
        ],
      );

      expect(
        tage(plan.toWrite),
        [beginn15],
        reason: '23:30 UTC im Januar ist 00:30 Berliner Zeit des Folgetags',
      );
    });

    test('Im Juli gilt Sommerzeit — 22:30 UTC ist schon der Folgetag', () {
      final plan = UmfangsImport.plan(
        existing: const [],
        incoming: [
          messung(DateTime.utc(2099, 7, 9, 22, 30), {Umfang.taille: 81.0}),
          messung(DateTime.utc(2099, 7, 9, 21, 30), {Umfang.brust: 102.0}),
        ],
      );

      expect(tage(plan.toWrite), [
        DateTime.utc(2099, 7, 8, 22),
        DateTime.utc(2099, 7, 9, 22),
      ]);
    });

    test('Die Tage stehen aufsteigend, gleich wie die Datei sortiert war', () {
      final plan = UmfangsImport.plan(
        existing: const [],
        incoming: [
          messung(vormittags21, {Umfang.taille: 80.0}),
          messung(vormittags14, {Umfang.taille: 81.0}),
        ],
      );

      expect(tage(plan.toWrite), [beginn14, beginn21]);
    });

    test('Zwei Einträge desselben Berliner Tages werden ein Tag', () {
      final plan = UmfangsImport.plan(
        existing: const [],
        incoming: [
          messung(vormittags14, {Umfang.taille: 81.0}),
          messung(abends14, {Umfang.brust: 102.0}),
        ],
      );

      expect(plan.toWrite, [
        messung(beginn14, {Umfang.taille: 81.0, Umfang.brust: 102.0}),
      ]);
    });

    test('Beim selben Tag und Maß gewinnt der spätere Eintrag der Liste', () {
      final plan = UmfangsImport.plan(
        existing: const [],
        incoming: [
          messung(abends14, {Umfang.taille: 83.0}),
          messung(vormittags14, {Umfang.taille: 81.0}),
        ],
      );

      expect(
        plan.toWrite.single.werte[Umfang.taille],
        81.0,
        reason: 'Dieselbe Regel, nach der `UmfangsMerge` faltet — die '
            'Reihenfolge legt der Leser fest, nicht die Uhrzeit',
      );
    });
  });

  /* ---- Was schon dasteht, bleibt ------------------------------------- */

  group('Was schon dasteht, bleibt', () {
    test('Ein Maß, das als Import schon dasteht, wird nicht geschrieben', () {
      final plan = UmfangsImport.plan(
        existing: [
          messung(beginn14, {Umfang.taille: 81.0}),
        ],
        incoming: [
          messung(vormittags14, {Umfang.taille: 81.0}),
        ],
      );

      expect(plan.toWrite, isEmpty);
      expect(plan.alreadyPresent, [
        messung(beginn14, {Umfang.taille: 81.0}),
      ]);
    });

    test('Ein anderer Wert für dasselbe Maß ändert nichts daran', () {
      final plan = UmfangsImport.plan(
        existing: [
          messung(beginn14, {Umfang.taille: 81.0}),
        ],
        incoming: [
          messung(vormittags14, {Umfang.taille: 79.0}),
        ],
      );

      expect(
        plan.toWrite,
        isEmpty,
        reason: 'Die Übernahme schreibt nur dazu; eine Korrektur in der '
            'alten Datei zöge sonst den Stand zurück',
      );
      expect(plan.alreadyPresent.single.werte[Umfang.taille], 79.0);
    });

    test('Maßweise: Am selben Tag kommt das neue Maß dazu, das alte bleibt', () {
      final plan = UmfangsImport.plan(
        existing: [
          messung(beginn14, {Umfang.taille: 81.0, Umfang.hals: 39.0}),
        ],
        incoming: [
          messung(vormittags14, {
            Umfang.taille: 81.0,
            Umfang.brust: 102.0,
            Umfang.wadeRechts: 39.5,
          }),
        ],
      );

      expect(plan.toWrite, [
        messung(beginn14, {Umfang.brust: 102.0, Umfang.wadeRechts: 39.5}),
      ]);
      expect(plan.alreadyPresent, [
        messung(beginn14, {Umfang.taille: 81.0}),
      ]);
    });

    test('Ein Tag, dessen Maße alle schon dastehen, fehlt in `toWrite` — '
        'auch nicht als leerer Tag', () {
      final plan = UmfangsImport.plan(
        existing: [
          messung(beginn14, {Umfang.taille: 81.0}),
          messung(beginn21, {Umfang.taille: 80.0}),
        ],
        incoming: [
          messung(vormittags14, {Umfang.taille: 81.0}),
          messung(vormittags21, {Umfang.taille: 80.0, Umfang.hals: 39.0}),
        ],
      );

      expect(tage(plan.toWrite), [beginn21]);
      expect(plan.toWrite.single.werte, {Umfang.hals: 39.0});
    });

    test('Ein vorhandener Tag, den die Datei nicht kennt, stört nicht', () {
      final plan = UmfangsImport.plan(
        existing: [
          messung(beginn21, {Umfang.taille: 80.0}),
        ],
        incoming: [
          messung(vormittags14, {Umfang.taille: 81.0}),
        ],
      );

      expect(plan.toWrite, [
        messung(beginn14, {Umfang.taille: 81.0}),
      ]);
      expect(plan.alreadyPresent, isEmpty);
    });

    test('Dasselbe Maß an einem anderen Tag ist etwas anderes', () {
      final plan = UmfangsImport.plan(
        existing: [
          messung(beginn14, {Umfang.taille: 81.0}),
        ],
        incoming: [
          messung(vormittags21, {Umfang.taille: 81.0}),
        ],
      );

      expect(tage(plan.toWrite), [beginn21]);
      expect(plan.alreadyPresent, isEmpty);
    });

    test('Der Tag des Vorhandenen wird ebenfalls auf Berliner Tage '
        'gerechnet', () {
      final plan = UmfangsImport.plan(
        existing: [
          messung(nachts15, {Umfang.taille: 81.0}),
        ],
        incoming: [
          messung(DateTime.utc(2099, 1, 15, 9), {Umfang.taille: 79.0}),
        ],
      );

      expect(
        plan.toWrite,
        isEmpty,
        reason: '00:30 und 10:00 Berliner Zeit sind derselbe Tag',
      );
      expect(tage(plan.alreadyPresent), [beginn15]);
    });

    test('`alreadyPresent` steht ebenfalls aufsteigend nach Tag', () {
      final plan = UmfangsImport.plan(
        existing: [
          messung(beginn21, {Umfang.taille: 80.0}),
          messung(beginn14, {Umfang.taille: 81.0}),
        ],
        incoming: [
          messung(vormittags21, {Umfang.taille: 80.0}),
          messung(vormittags14, {Umfang.taille: 81.0}),
        ],
      );

      expect(tage(plan.alreadyPresent), [beginn14, beginn21]);
    });
  });

  /* ---- Zweimal dieselbe Datei ---------------------------------------- */

  group('Zweimal dieselbe Datei verdoppelt nichts', () {
    test('Der zweite Lauf gegen das Ergebnis des ersten schreibt nichts', () {
      final ausDerDatei = [
        messung(vormittags14, {Umfang.taille: 81.0, Umfang.brust: 102.0}),
        messung(vormittags21, {Umfang.taille: 80.0}),
      ];

      final erster = UmfangsImport.plan(
        existing: const [],
        incoming: ausDerDatei,
      );
      final zweiter = UmfangsImport.plan(
        existing: erster.toWrite,
        incoming: ausDerDatei,
      );

      expect(erster.toWrite, hasLength(2));
      expect(zweiter.toWrite, isEmpty);
      expect(zweiter.alreadyPresent, erster.toWrite);
    });

    test('Eine gewachsene Datei bringt genau die neuen Werte', () {
      final erster = UmfangsImport.plan(
        existing: const [],
        incoming: [
          messung(vormittags14, {Umfang.taille: 81.0}),
        ],
      );

      final zweiter = UmfangsImport.plan(
        existing: erster.toWrite,
        incoming: [
          messung(vormittags14, {Umfang.taille: 81.0, Umfang.hals: 39.0}),
          messung(vormittags21, {Umfang.taille: 80.0}),
        ],
      );

      expect(zweiter.toWrite, [
        messung(beginn14, {Umfang.hals: 39.0}),
        messung(beginn21, {Umfang.taille: 80.0}),
      ]);
    });

    test('Der Plan ist eine reine Funktion: zweimal gerufen, zweimal '
        'dasselbe', () {
      final eingabe = [
        messung(abends14, {Umfang.brust: 102.0}),
        messung(vormittags14, {Umfang.taille: 81.0}),
      ];
      final vorhanden = [
        messung(beginn14, {Umfang.hals: 39.0}),
      ];

      final a = UmfangsImport.plan(existing: vorhanden, incoming: eingabe);
      final b = UmfangsImport.plan(existing: vorhanden, incoming: eingabe);

      expect(a.toWrite, b.toWrite);
      expect(a.alreadyPresent, b.alreadyPresent);
      expect(
        eingabe.first.werte,
        {Umfang.brust: 102.0},
        reason: 'Der Planer schreibt nicht in die übergebenen Messungen',
      );
    });
  });
}
