import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `NightVitals` aus Ticket #193 — Spec
/// `docs/superpowers/specs/2026-11-02-193-nachtwerte.md`, Abschnitt
/// „Stufe 1 — Die Kernformel".
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## Worum es geht
///
/// Der Ruhepuls, den die App bisher zeigt, ist Apples `RestingHeartRate` —
/// ein **Tageswert**, der im Lauf des Tages mitwächst. HRV und Atemfrequenz
/// hat die App über den ganzen Kalendertag gemittelt. Beides beantwortet die
/// Frage „wie war die Nacht?" nicht. Diese Datei hält die Gegenrechnung
/// fest: drei Werte, alle drei **aus dem Schlaffenster**.
///
/// **Von Tim am 02.11.2026 entschieden** (Auswahlmenü auf Grundlage der
/// Tabelle in #193):
///
/// - Der Ruhepuls einer Nacht ist das **5. Perzentil** der Pulsproben im
///   Fenster — der tiefste anhaltende Wert, nicht der tiefste Einzelwert.
/// - **Alle drei** Werte kommen aus dem Nachtfenster, auch die Atemfrequenz.
///
/// **Vom Koordinator entschieden, nicht von Tim:** dass HRV und Atemfrequenz
/// der **Median** der Proben im Fenster sind und nicht das Mittel. Das steht
/// so in der Spec und wird hier entsprechend festgehalten; es ist keine
/// Entscheidung, die Tim vorgelegt wurde.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// class VitalSample {
///   const VitalSample({required this.time, required this.value});
///   final DateTime time;
///   final double value;
///   // Wertgleichheit: == und hashCode.
/// }
///
/// class NightVitals {
///   const NightVitals({this.restingHeartRate, this.hrv, this.respiratoryRate});
///   final double? restingHeartRate;
///   final double? hrv;
///   final double? respiratoryRate;
///
///   static NightVitals from({
///     required List<VitalSample> heartRate,
///     required List<VitalSample> hrv,
///     required List<VitalSample> respiratoryRate,
///     required DateTime from,
///     required DateTime through,
///   });
/// }
/// ```
///
/// Importiert wird das Barrel-File `package:trainings_core/trainings_core.dart`
/// und nicht `lib/src/night_vitals.dart` direkt: Die Spec verlangt den Export
/// aus `lib/trainings_core.dart` ausdrücklich, und über das Barrel ist er
/// mitgeprüft. Solange `lib/src/night_vitals.dart` fehlt, übersetzt diese
/// Datei nicht — das ist der erwartete RED-Zustand vor der Umsetzung.
///
/// ## Zwei Dinge, die diese Datei bewusst mitprüft
///
/// **Wertgleichheit auch für `NightVitals`.** Die Spec schreibt `==`/`hashCode`
/// nur für `VitalSample` vor. `NightVitals` wandert in Stufe 3 aber ebenfalls
/// in einen Provider (je Nacht eines, unter dem Tagesschlüssel), und ohne
/// Wertgleichheit wäre jede neu gebaute Nacht ungleich der vorigen — genau der
/// Fehler `03` aus `CLAUDE.md`, eine Ebene tiefer. Diese Forderung stammt aus
/// der Hausregel, nicht aus der Spec; sie ist hier bewusst ergänzt.
///
/// **Der Zeitpunkt entscheidet, nicht die Schreibweise.** Darts `DateTime.==`
/// vergleicht `isUtc` mit; zwei `DateTime`, die denselben Augenblick meinen,
/// sind **ungleich**, wenn der eine UTC und der andere Ortszeit ist.
/// `isBefore`/`isAfter`/`compareTo` kennen das Problem nicht. Eine
/// Fensterprüfung, die den Rand über `==` abfängt (`t == from || t.isAfter(from)`),
/// verliert deshalb genau die Probe, die auf dem Rand liegt, sobald sie als
/// Ortszeit hereinkommt. Die Gruppe „Zeitzonen" unten prüft das. Die
/// Ortszeit-Werte entstehen über `toLocal()` auf einem UTC-Zeitpunkt und
/// bezeichnen damit auf jeder Maschine denselben Augenblick wie ihr Original —
/// unabhängig davon, wie die Maschine eingestellt ist.
///
/// **Alle Zahlen hier sind erfunden.** Glatte Reihen wie 40, 41, 42 … tragen
/// keine Gesundheitsbedeutung und sind genau deshalb gewählt: Ein Perzentil
/// darüber lässt sich auf Papier nachrechnen, und das steht bei den
/// betreffenden Fällen im Kommentar. Die Zahlen aus #193 sind Analyse echter
/// Messungen und gehören nicht in eine Testdatei.
void main() {
  // Ein erfundenes Schlaffenster. Fenstergrenzen sind hier echte Zeitpunkte
  // (Einschlafen und Aufwachen), keine Kalendertage — `BerlinCalendar` hat
  // damit nichts zu tun.
  final einschlafen = DateTime.utc(2026, 6, 10, 21, 30);
  final aufwachen = DateTime.utc(2026, 6, 11, 5, 45);

  /// Baut eine Probenreihe ab `start`, je `abstand` eine Probe.
  List<VitalSample> reihe(
    DateTime start,
    List<double> werte, {
    Duration abstand = const Duration(minutes: 5),
  }) => [
    for (var i = 0; i < werte.length; i++)
      VitalSample(time: start.add(abstand * i), value: werte[i]),
  ];

  /// Ruft `NightVitals.from` mit dem Standardfenster und leeren Reihen als
  /// Vorgabe — damit jeder Test nur das nennt, worum es ihm geht.
  NightVitals rechne({
    List<VitalSample> puls = const [],
    List<VitalSample> hrv = const [],
    List<VitalSample> atmung = const [],
    DateTime? von,
    DateTime? bis,
  }) => NightVitals.from(
    heartRate: puls,
    hrv: hrv,
    respiratoryRate: atmung,
    from: von ?? einschlafen,
    through: bis ?? aufwachen,
  );

  group('Ruhepuls: das 5. Perzentil, linear interpoliert', () {
    test('acht Proben — der Interpolationsfall, von Hand nachgerechnet', () {
      // Von Hand nachgerechnet, damit später nachvollziehbar bleibt, woher
      // der Erwartungswert kommt:
      //
      //   aufsteigend sortiert: 40, 41, 42, 43, 44, 45, 46, 47   (n = 8)
      //   k = (n - 1) * 0.05 = 7 * 0.05 = 0.35
      //   k.floor() = 0, k.ceil() = 1, k - k.floor() = 0.35
      //   xs[0] + (xs[1] - xs[0]) * 0.35
      //     = 40 + (41 - 40) * 0.35
      //     = 40.35
      //
      // Der tiefste Einzelwert wäre 40, das Mittel 43,5 — beide Zahlen
      // würden hier danebenliegen und fielen auf.
      final ergebnis = rechne(
        puls: reihe(einschlafen, const [40, 41, 42, 43, 44, 45, 46, 47]),
      );

      expect(ergebnis.restingHeartRate, closeTo(40.35, 1e-9));
    });

    test('fünf Proben — k ist 0,2 und liegt zwischen den ersten beiden', () {
      //   sortiert: 10, 20, 30, 40, 50   (n = 5)
      //   k = 4 * 0.05 = 0.2
      //   xs[0] + (xs[1] - xs[0]) * 0.2 = 10 + 10 * 0.2 = 12.0
      final ergebnis = rechne(
        puls: reihe(einschlafen, const [10, 20, 30, 40, 50]),
      );

      expect(ergebnis.restingHeartRate, closeTo(12.0, 1e-9));
    });

    test('einundzwanzig Proben — k ist ganzzahlig, es wird nicht '
        'interpoliert', () {
      //   sortiert: 50, 51, 52, … 70   (n = 21)
      //   k = 20 * 0.05 = 1.0
      //   k.floor() = k.ceil() = 1  →  xs[1] = 51
      final werte = List<double>.generate(21, (i) => (50 + i).toDouble());
      final ergebnis = rechne(puls: reihe(einschlafen, werte));

      expect(ergebnis.restingHeartRate, closeTo(51.0, 1e-9));
    });

    test('ein einzelner Ausreißer nach unten wird nicht zum Ruhepuls', () {
      // Genau der Grund für das Perzentil statt des Minimums (Tim,
      // 02.11.2026): „der tiefste anhaltende Wert, nicht der tiefste
      // Einzelwert".
      //
      //   sortiert: 35, dann zwanzigmal 60   (n = 21)
      //   k = 20 * 0.05 = 1.0  →  xs[1] = 60
      //
      // Das Minimum wäre 35 — eine einzelne verirrte Messung, die sich als
      // Ruhepuls ausgäbe.
      final werte = <double>[35, ...List<double>.filled(20, 60)];
      final ergebnis = rechne(puls: reihe(einschlafen, werte));

      expect(ergebnis.restingHeartRate, closeTo(60.0, 1e-9));
    });

    test('lauter gleiche Proben ergeben genau diesen Wert', () {
      final ergebnis = rechne(
        puls: reihe(einschlafen, List<double>.filled(9, 58)),
      );

      expect(ergebnis.restingHeartRate, closeTo(58.0, 1e-9));
    });

    test('unsortierte Eingabe liefert dasselbe wie sortierte', () {
      // Dieselbe Menge, einmal in Wertreihenfolge und einmal durcheinander.
      // Sortiert wird nach dem Wert, nicht nach der Zeit — die Zeit bestimmt
      // nur, ob eine Probe überhaupt ins Fenster gehört.
      final sortiert = rechne(
        puls: reihe(einschlafen, const [40, 41, 42, 43, 44, 45, 46, 47]),
      );
      final durcheinander = rechne(
        puls: reihe(einschlafen, const [45, 41, 47, 43, 40, 46, 42, 44]),
      );

      expect(durcheinander.restingHeartRate, sortiert.restingHeartRate);
      expect(durcheinander.restingHeartRate, closeTo(40.35, 1e-9));
    });
  });

  group('Ruhepuls: mindestens fünf Proben, sonst null', () {
    test('genau fünf Proben ergeben einen Wert', () {
      final ergebnis = rechne(
        puls: reihe(einschlafen, const [60, 61, 62, 63, 64]),
      );

      //   k = 4 * 0.05 = 0.2  →  60 + (61 - 60) * 0.2 = 60.2
      expect(ergebnis.restingHeartRate, closeTo(60.2, 1e-9));
    });

    test('genau vier Proben ergeben null', () {
      final ergebnis = rechne(puls: reihe(einschlafen, const [60, 61, 62, 63]));

      expect(ergebnis.restingHeartRate, isNull);
    });

    test('eine einzelne Probe ergibt null, nicht sich selbst', () {
      final ergebnis = rechne(puls: reihe(einschlafen, const [58]));

      expect(ergebnis.restingHeartRate, isNull);
    });

    test('gezählt werden die Proben im Fenster, nicht die übergebenen', () {
      // Neun Proben insgesamt, aber nur vier in der Nacht: zu wenig.
      final ergebnis = rechne(
        puls: [
          ...reihe(einschlafen.subtract(const Duration(hours: 6)), const [
            90,
            91,
            92,
            93,
            94,
          ]),
          ...reihe(einschlafen, const [60, 61, 62, 63]),
        ],
      );

      expect(ergebnis.restingHeartRate, isNull);
    });

    test('fünf Proben im Fenster genügen, auch wenn davor welche liegen', () {
      final ergebnis = rechne(
        puls: [
          ...reihe(einschlafen.subtract(const Duration(hours: 6)), const [
            90,
            91,
            92,
          ]),
          ...reihe(einschlafen, const [60, 61, 62, 63, 64]),
        ],
      );

      expect(ergebnis.restingHeartRate, closeTo(60.2, 1e-9));
    });
  });

  group('HRV und Atemfrequenz: der Median der Proben im Fenster', () {
    test('ungerade Anzahl — der mittlere Wert', () {
      final ergebnis = rechne(hrv: reihe(einschlafen, const [10, 20, 30, 40, 50]));

      expect(ergebnis.hrv, 30.0);
    });

    test('gerade Anzahl — das Mittel der beiden mittleren Werte', () {
      // Achtung, hier weicht die Regel von `HealthMedian.value` ab: dort
      // gewinnt bei gerader Anzahl der **obere** der beiden mittleren Werte,
      // hier wird gemittelt. So steht es in der Spec zu #193
      // („Median bei gerader Anzahl: Mittel der beiden mittleren Werte").
      //
      //   sortiert: 10, 20, 30, 40  →  (20 + 30) / 2 = 25
      final ergebnis = rechne(hrv: reihe(einschlafen, const [10, 20, 30, 40]));

      expect(ergebnis.hrv, 25.0);
    });

    test('gerade Anzahl mit gleichen mittleren Werten', () {
      //   sortiert: 10, 20, 20, 40  →  (20 + 20) / 2 = 20
      final ergebnis = rechne(hrv: reihe(einschlafen, const [40, 20, 10, 20]));

      expect(ergebnis.hrv, 20.0);
    });

    test('unsortierte Eingabe ergibt denselben Median', () {
      final ergebnis = rechne(hrv: reihe(einschlafen, const [50, 10, 40, 30, 20]));

      expect(ergebnis.hrv, 30.0);
    });

    test('eine einzelne Probe genügt — es gibt keine Mindestzahl', () {
      // Die Uhr misst HRV zwei- bis sechsmal je Nacht; eine Mindestzahl wie
      // beim Puls würde hier fast jede Nacht abschalten.
      final ergebnis = rechne(hrv: reihe(einschlafen, const [42]));

      expect(ergebnis.hrv, 42.0);
    });

    test('zwei Proben ergeben ihr Mittel', () {
      final ergebnis = rechne(hrv: reihe(einschlafen, const [40, 50]));

      expect(ergebnis.hrv, 45.0);
    });

    test('die Atemfrequenz folgt derselben Regel', () {
      //   sortiert: 13, 14, 15, 16  →  (14 + 15) / 2 = 14.5
      final ergebnis = rechne(atmung: reihe(einschlafen, const [16, 13, 15, 14]));

      expect(ergebnis.respiratoryRate, 14.5);
    });

    test('vier Proben: HRV und Atmung liefern, der Puls nicht', () {
      // Die Mindestzahl gilt allein für den Puls. Derselbe Satz Proben,
      // dreimal eingereicht — zwei Felder tragen, eines nicht.
      final ergebnis = rechne(
        puls: reihe(einschlafen, const [60, 61, 62, 63]),
        hrv: reihe(einschlafen, const [10, 20, 30, 40]),
        atmung: reihe(einschlafen, const [10, 20, 30, 40]),
      );

      expect(ergebnis.restingHeartRate, isNull);
      expect(ergebnis.hrv, 25.0);
      expect(ergebnis.respiratoryRate, 25.0);
    });
  });

  group('Das Fenster schließt beide Ränder ein', () {
    test('eine Probe genau auf `from` zählt mit', () {
      final ergebnis = rechne(
        hrv: [VitalSample(time: einschlafen, value: 44)],
      );

      expect(ergebnis.hrv, 44.0);
    });

    test('eine Probe genau auf `through` zählt mit', () {
      final ergebnis = rechne(hrv: [VitalSample(time: aufwachen, value: 44)]);

      expect(ergebnis.hrv, 44.0);
    });

    test('eine Mikrosekunde vor `from` bleibt draußen', () {
      final ergebnis = rechne(
        hrv: [
          VitalSample(
            time: einschlafen.subtract(const Duration(microseconds: 1)),
            value: 44,
          ),
        ],
      );

      expect(ergebnis.hrv, isNull);
    });

    test('eine Mikrosekunde nach `through` bleibt draußen', () {
      final ergebnis = rechne(
        hrv: [
          VitalSample(
            time: aufwachen.add(const Duration(microseconds: 1)),
            value: 44,
          ),
        ],
      );

      expect(ergebnis.hrv, isNull);
    });

    test('Tagesproben vor und nach der Nacht verschieben nichts', () {
      // Fünf Nachtproben, dazu ein hoher Tageswert davor und ein absurd
      // tiefer danach. Käme auch nur eine der beiden herein, stünde hier
      // nicht 52,4 — genau das ist der Fehler, gegen den #193 gebaut wird.
      //
      //   sortiert (nur Nacht): 52, 54, 56, 58, 60   (n = 5)
      //   k = 4 * 0.05 = 0.2
      //   52 + (54 - 52) * 0.2 = 52.4
      final nurNacht = rechne(
        puls: reihe(einschlafen, const [52, 54, 56, 58, 60]),
      );
      final mitTag = rechne(
        puls: [
          VitalSample(
            time: einschlafen.subtract(const Duration(minutes: 1)),
            value: 118,
          ),
          ...reihe(einschlafen, const [52, 54, 56, 58, 60]),
          VitalSample(
            time: aufwachen.add(const Duration(minutes: 1)),
            value: 31,
          ),
        ],
      );

      expect(nurNacht.restingHeartRate, closeTo(52.4, 1e-9));
      expect(mitTag.restingHeartRate, nurNacht.restingHeartRate);
    });

    test('`through` vor `from` ergibt ein leeres Fenster', () {
      final ergebnis = rechne(
        puls: reihe(einschlafen, const [60, 61, 62, 63, 64, 65]),
        hrv: reihe(einschlafen, const [40, 50, 60]),
        atmung: reihe(einschlafen, const [13, 14, 15]),
        von: aufwachen,
        bis: einschlafen,
      );

      expect(ergebnis.restingHeartRate, isNull);
      expect(ergebnis.hrv, isNull);
      expect(ergebnis.respiratoryRate, isNull);
    });
  });

  group('Ein Fenster der Länge null', () {
    test('nimmt genau die Probe auf diesem Zeitpunkt', () {
      final ergebnis = rechne(
        hrv: [
          VitalSample(
            time: einschlafen.subtract(const Duration(microseconds: 1)),
            value: 10,
          ),
          VitalSample(time: einschlafen, value: 44),
          VitalSample(
            time: einschlafen.add(const Duration(microseconds: 1)),
            value: 99,
          ),
        ],
        von: einschlafen,
        bis: einschlafen,
      );

      expect(ergebnis.hrv, 44.0);
    });

    test('fünf Pulsproben auf demselben Zeitpunkt ergeben ein Perzentil', () {
      //   sortiert: 60, 61, 62, 63, 64  →  k = 0.2  →  60.2
      final ergebnis = rechne(
        puls: [
          for (final wert in const [62.0, 60.0, 64.0, 61.0, 63.0])
            VitalSample(time: aufwachen, value: wert),
        ],
        von: aufwachen,
        bis: aufwachen,
      );

      expect(ergebnis.restingHeartRate, closeTo(60.2, 1e-9));
    });
  });

  group('Zeitzonen: verglichen wird der Zeitpunkt, nicht die Schreibweise', () {
    test('eine Ortszeit-Probe genau auf `from` zählt mit', () {
      // `toLocal()` bezeichnet denselben Augenblick wie `einschlafen`, trägt
      // aber `isUtc == false`. Darts `DateTime.==` hält die beiden deshalb
      // für ungleich; `isBefore`/`isAfter` nicht. Wer den Rand über `==`
      // abfängt, verliert genau diese Probe.
      final ergebnis = rechne(
        hrv: [VitalSample(time: einschlafen.toLocal(), value: 44)],
      );

      expect(ergebnis.hrv, 44.0);
    });

    test('eine Ortszeit-Probe genau auf `through` zählt mit', () {
      final ergebnis = rechne(
        hrv: [VitalSample(time: aufwachen.toLocal(), value: 44)],
      );

      expect(ergebnis.hrv, 44.0);
    });

    test('Ortszeit-Proben im Fenster zählen, außerhalb nicht', () {
      final drinnen = einschlafen.add(const Duration(hours: 2)).toLocal();
      final draussen = aufwachen.add(const Duration(hours: 2)).toLocal();
      final ergebnis = rechne(
        hrv: [
          VitalSample(time: drinnen, value: 44),
          VitalSample(time: draussen, value: 900),
        ],
      );

      expect(ergebnis.hrv, 44.0);
    });

    test('ein Ortszeit-Fenster liefert dasselbe wie das UTC-Fenster', () {
      final proben = reihe(einschlafen, const [52, 54, 56, 58, 60]);
      final inUtc = rechne(puls: proben);
      final inOrtszeit = rechne(
        puls: proben,
        von: einschlafen.toLocal(),
        bis: aufwachen.toLocal(),
      );

      expect(inUtc.restingHeartRate, closeTo(52.4, 1e-9));
      expect(inOrtszeit.restingHeartRate, inUtc.restingHeartRate);
    });

    test('die Ränder gelten auch bei gemischter Schreibweise', () {
      // Fenster in Ortszeit, Proben in UTC, und beide Proben liegen genau
      // auf einem Rand.
      final ergebnis = rechne(
        hrv: [
          VitalSample(time: einschlafen, value: 40),
          VitalSample(time: aufwachen, value: 50),
        ],
        von: einschlafen.toLocal(),
        bis: aufwachen.toLocal(),
      );

      expect(ergebnis.hrv, 45.0);
    });
  });

  group('Leer heißt null, nicht 0', () {
    test('drei leere Reihen ergeben lauter null', () {
      final ergebnis = rechne();

      expect(ergebnis.restingHeartRate, isNull);
      expect(ergebnis.hrv, isNull);
      expect(ergebnis.respiratoryRate, isNull);
    });

    test('drei leere Reihen ergeben die leere Nacht', () {
      expect(rechne(), const NightVitals());
    });

    test('keine Probe im Fenster ergibt null, nicht 0', () {
      // Proben sind da, nur eben am Tag. Eine 0 hier wäre Fehler `01` aus
      // `CLAUDE.md`, eine Ebene tiefer: „nichts gemessen" sähe aus wie
      // „Ruhepuls null".
      final tagsueber = aufwachen.add(const Duration(hours: 4));
      final ergebnis = rechne(
        puls: reihe(tagsueber, const [90, 91, 92, 93, 94, 95]),
        hrv: reihe(tagsueber, const [40, 50, 60]),
        atmung: reihe(tagsueber, const [13, 14, 15]),
      );

      expect(ergebnis.restingHeartRate, isNull);
      expect(ergebnis.hrv, isNull);
      expect(ergebnis.respiratoryRate, isNull);
      expect(ergebnis.restingHeartRate, isNot(0));
      expect(ergebnis.hrv, isNot(0));
      expect(ergebnis.respiratoryRate, isNot(0));
    });

    test('eine fehlende Reihe schaltet nur ihr eigenes Feld ab', () {
      final ergebnis = rechne(
        puls: reihe(einschlafen, const [60, 61, 62, 63, 64]),
        atmung: reihe(einschlafen, const [13, 14, 15]),
      );

      expect(ergebnis.restingHeartRate, closeTo(60.2, 1e-9));
      expect(ergebnis.hrv, isNull);
      expect(ergebnis.respiratoryRate, 14.0);
    });
  });

  group('Die übergebenen Listen bleiben unverändert', () {
    test('eine unsortierte Liste behält ihre Reihenfolge', () {
      // Ein `sort()` auf der Eingabe wäre eine stille Nebenwirkung beim
      // Aufrufer: Stufe 3 reicht dieselben Proben nacheinander an dreißig
      // Nächte weiter.
      final eingabe = reihe(einschlafen, const [45, 41, 47, 43, 40, 46, 42, 44]);
      final vorher = [...eingabe];

      rechne(puls: eingabe);

      expect(eingabe, vorher);
      expect(
        eingabe.map((probe) => probe.value).toList(),
        const [45.0, 41.0, 47.0, 43.0, 40.0, 46.0, 42.0, 44.0],
      );
    });

    test('alle drei Listen bleiben unberührt', () {
      final puls = reihe(einschlafen, const [64, 60, 62, 61, 63]);
      final hrv = reihe(einschlafen, const [50, 10, 30]);
      final atmung = reihe(einschlafen, const [15, 13, 14]);
      final pulsVorher = [...puls];
      final hrvVorher = [...hrv];
      final atmungVorher = [...atmung];

      rechne(puls: puls, hrv: hrv, atmung: atmung);

      expect(puls, pulsVorher);
      expect(hrv, hrvVorher);
      expect(atmung, atmungVorher);
    });

    test('eine unveränderliche Liste wird nicht sortiert', () {
      // Der schärfere Beweis: `List.unmodifiable` wirft beim ersten
      // Schreibzugriff. Wer in der Eingabe sortiert, kommt hier nicht durch.
      final puls = List<VitalSample>.unmodifiable(
        reihe(einschlafen, const [64, 60, 62, 61, 63]),
      );
      final hrv = List<VitalSample>.unmodifiable(
        reihe(einschlafen, const [50, 10, 30]),
      );
      final atmung = List<VitalSample>.unmodifiable(
        reihe(einschlafen, const [15, 13, 14]),
      );

      final ergebnis = rechne(puls: puls, hrv: hrv, atmung: atmung);

      //   Puls sortiert: 60, 61, 62, 63, 64  →  k = 0.2  →  60.2
      expect(ergebnis.restingHeartRate, closeTo(60.2, 1e-9));
      expect(ergebnis.hrv, 30.0);
      expect(ergebnis.respiratoryRate, 14.0);
    });
  });

  group('Werttypen: == und hashCode', () {
    test('zwei VitalSample mit gleicher Zeit und gleichem Wert sind gleich', () {
      final a = VitalSample(time: einschlafen, value: 60);
      final b = VitalSample(time: DateTime.utc(2026, 6, 10, 21, 30), value: 60);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect({a, b}, hasLength(1));
    });

    test('eine andere Zeit oder ein anderer Wert macht sie ungleich', () {
      final a = VitalSample(time: einschlafen, value: 60);

      expect(
        a,
        isNot(VitalSample(time: einschlafen.add(const Duration(minutes: 1)), value: 60)),
      );
      expect(a, isNot(VitalSample(time: einschlafen, value: 61)));
    });

    test('zwei NightVitals mit gleichen Werten sind gleich', () {
      // Nicht aus der Spec, sondern aus der Hausregel (`CLAUDE.md`): In
      // Stufe 3 hängt ein Provider an diesen Nächten, und ohne
      // Wertgleichheit rechnete jeder abgeleitete Wert bei jedem Durchlauf
      // neu.
      const a = NightVitals(restingHeartRate: 52.4, hrv: 30, respiratoryRate: 14);
      const b = NightVitals(restingHeartRate: 52.4, hrv: 30, respiratoryRate: 14);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect({a, b}, hasLength(1));
    });

    test('ein anderer Wert macht sie ungleich — auch null gegen eine Zahl', () {
      const voll = NightVitals(restingHeartRate: 52.4, hrv: 30, respiratoryRate: 14);

      expect(voll, isNot(const NightVitals(restingHeartRate: 52.4, hrv: 30)));
      expect(const NightVitals(hrv: 0), isNot(const NightVitals()));
    });
  });
}
