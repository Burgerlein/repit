// Datei rein, Bericht raus (#59 Teil 1, mit #482): Bytes einer
// `trainingsexport`-Datei der eingefrorenen Swift-App werden gelesen, die
// Ablage schreibt dazu, und der Bericht sagt, was passiert ist.
//
// Spec: `docs/superpowers/specs/2026-11-11-gym-uebernahme-design.md`,
// Abschnitte 6, 9, 10 und 15; Tests:
// `test/data/trainingsexport_uebernahme_test.dart` und — für die Umfänge
// (#498) — `test/data/umfaenge_uebernahme_test.dart`.
//
// Die Rechnungen stehen im Kern (`TrainingsExport.read`,
// `GymSessionImport.plan`); hier ist nur die Plattformseite: Bytes → Text →
// `jsonDecode` (`dart:convert` ist dem Kern verboten) und der Aufruf der
// Ablage. **Für Dateien wirft diese Funktion nie** — eine kaputte, fremde
// oder zu alte Datei ist ein Ergebnis, kein Absturz. Wirft die **Ablage**
// (Platte voll), kommt der Fehler heraus; den fängt der Schirm.
import 'dart:convert';
import 'dart:typed_data';

import 'package:trainings_core/trainings_core.dart';

import '../data/gym_repository.dart';
import '../data/umfaenge_repository.dart';

/// Was aus einer Exportdatei geworden ist.
sealed class TrainingsexportErgebnis {
  const TrainingsexportErgebnis();
}

/// Die Datei wurde nicht gelesen — mit dem Grund. **Nichts ist
/// geschrieben.**
final class TrainingsexportAbgelehnt extends TrainingsexportErgebnis {
  const TrainingsexportAbgelehnt(this.grund);

  /// Aus dem Kern; [NotJson] baut diese Funktion, wenn schon das Dekodieren
  /// scheitert.
  final ExportRejection grund;

  @override
  String toString() => 'TrainingsexportAbgelehnt($grund)';
}

/// Die Datei wurde gelesen und die Ablage hat geschrieben, was sie durfte.
///
/// **Die Zahlen gehen auf:**
/// `inDatei == neu + schonDa + nichtUebernommen + nichtLesbar.length`.
final class TrainingsexportUebernommen extends TrainingsexportErgebnis {
  const TrainingsexportUebernommen({
    required this.erzeugtAm,
    required this.zeitzone,
    required this.geschrieben,
    required this.uebersprungen,
    required this.nichtLesbar,
    required this.unbekannteUebungen,
    required this.unbekannteWorkouts,
    required this.ungelesen,
    required this.umfaengeGeschrieben,
    required this.umfaengeSchonVorhanden,
    required this.umfaengeNichtLesbar,
    required this.unbekannteMasse,
  });

  /// `generated` der Datei, UTC.
  final DateTime erzeugtAm;

  /// `timezone` der Datei.
  final String zeitzone;

  /// Neu in der Ablage.
  final List<ImportedSession> geschrieben;

  /// Vom Planer nicht geschrieben, mit Grund.
  final List<GymImportSkip> uebersprungen;

  /// Vom Leser nicht gelesen, mit Position und Grund.
  final List<ExportSessionSkip> nichtLesbar;

  /// Übungs-IDs der Datei, die der Katalog nicht kennt — sortiert.
  final List<String> unbekannteUebungen;

  /// Workout-Codes der Datei, die der Kern nicht kennt — sortiert.
  final List<String> unbekannteWorkouts;

  /// Was die Datei trug und dieser Schritt nicht liest (`ExportRead.unread`).
  ///
  /// `circumferences` steht seit #498 nicht mehr darin — die Umfänge werden
  /// gelesen.
  final Map<String, int> ungelesen;

  /// Die neu geschriebenen Umfänge, tagweise und aufsteigend. Ohne
  /// Umfänge-Ablage leer: Dann wird nichts geschrieben.
  final List<Umfangsmessung> umfaengeGeschrieben;

  /// Je Tag die Maße, die als Import schon dastanden.
  final List<Umfangsmessung> umfaengeSchonVorhanden;

  /// Umfangswerte der Datei, die nicht gelesen wurden — mit Quelle,
  /// Position und Grund.
  final List<ExportMeasureSkip> umfaengeNichtLesbar;

  /// Maß-Schlüssel der Datei, die der Kern nicht kennt — sortiert.
  final List<String> unbekannteMasse;

  /// Jede Sitzung der Datei, gelesen oder nicht.
  int get inDatei =>
      geschrieben.length + uebersprungen.length + nichtLesbar.length;

  /// Neu in der Ablage.
  int get neu => geschrieben.length;

  /// Mit derselben Kennung schon da.
  int get schonDa => uebersprungen
      .where((s) => s.reason == GymImportSkipReason.alreadyPresent)
      .length;

  /// Tag und Workout belegt, oder Dublette in der Datei.
  int get nichtUebernommen => uebersprungen.length - schonDa;

  /// Zahl der **Einzelwerte**, die neu geschrieben wurden — nicht der Tage.
  /// Ein Tag trägt zwischen einem und fünfzehn Maßen.
  int get umfaengeNeu =>
      umfaengeGeschrieben.fold<int>(0, (summe, m) => summe + m.werte.length);

  /// Zahl der Einzelwerte, die als Import schon dastanden.
  int get umfaengeSchonDa =>
      umfaengeSchonVorhanden.fold<int>(0, (summe, m) => summe + m.werte.length);

  /// Zahl der Tage, an denen etwas dazukam.
  int get umfaengeTage => umfaengeGeschrieben.length;

  /// Sätze der geschriebenen Sitzungen.
  int get saetze => geschrieben.fold<int>(0, (summe, s) => summe + s.setCount);

  /// Berliner ISO-Tag der ältesten **geschriebenen** Sitzung, `null` wenn
  /// keine geschrieben wurde.
  String? get ersterTag => _tage.isEmpty ? null : _tage.first;

  /// Berliner ISO-Tag der jüngsten geschriebenen Sitzung.
  String? get letzterTag => _tage.isEmpty ? null : _tage.last;

  List<String> get _tage =>
      [for (final s in geschrieben) BerlinCalendar.dayKey(s.date)]..sort();

  @override
  String toString() =>
      'TrainingsexportUebernommen($neu neu, $schonDa schon da, '
      '$nichtUebernommen nicht übernommen, ${nichtLesbar.length} nicht '
      'lesbar)';
}

/// Liest [bytes] als Exportdatei und lässt [ablage] schreiben, was der Kern
/// erlaubt.
///
/// Kein halber Import: Wird die Datei abgelehnt, steht nichts in der
/// Ablage — auch keine Umfänge. Geschrieben wird über
/// [GymRepository.uebernimm] und [UmfaengeRepository.uebernimm] — nur dazu,
/// nie ersetzen.
///
/// [umfaenge] ist **benannt und nicht verlangt**: Fehlt die Ablage, wird
/// kein Umfang geschrieben und der Bericht nennt keine. Gelesen werden sie
/// trotzdem immer — `ExportRead` trägt sie, und `circumferences` fällt aus
/// `unread` heraus. Dass der echte Weg die Ablage wirklich mitgibt, nagelt
/// `test/uebernahme/uebernahme_umfaenge_test.dart` fest.
Future<TrainingsexportErgebnis> uebernimmTrainingsexport(
  GymRepository ablage,
  Uint8List bytes, {
  UmfaengeRepository? umfaenge,
}) async {
  final Object? dekodiert;
  try {
    // Ohne `allowMalformed`: Ungültiges UTF-8 ist keine Datei, die man
    // „so gut es geht" liest.
    var text = utf8.decode(bytes);
    if (text.startsWith('﻿')) text = text.substring(1);
    dekodiert = jsonDecode(text);
  } on FormatException catch (e) {
    return TrainingsexportAbgelehnt(
      NotJson(e.message.isEmpty ? 'Das ist kein lesbares JSON.' : e.message),
    );
  }

  final gelesen = TrainingsExport.read(dekodiert);
  switch (gelesen) {
    case ExportRejected(:final reason):
      return TrainingsexportAbgelehnt(reason);
    case ExportRead():
      final ergebnis = await ablage.uebernimm(gelesen.sessions);
      final umfaengeErgebnis = await umfaenge?.uebernimm(
        gelesen.circumferences,
      );
      return TrainingsexportUebernommen(
        erzeugtAm: gelesen.generated,
        zeitzone: gelesen.timezone,
        geschrieben: ergebnis.geschrieben,
        uebersprungen: ergebnis.uebersprungen,
        nichtLesbar: gelesen.skipped,
        unbekannteUebungen: gelesen.unknownExerciseIds,
        unbekannteWorkouts: gelesen.unknownWorkoutCodes,
        ungelesen: gelesen.unread,
        umfaengeGeschrieben: umfaengeErgebnis?.geschrieben ?? const [],
        umfaengeSchonVorhanden: umfaengeErgebnis?.schonVorhanden ?? const [],
        umfaengeNichtLesbar: gelesen.skippedMeasures,
        unbekannteMasse: gelesen.unknownMeasureKeys,
      );
  }
}
