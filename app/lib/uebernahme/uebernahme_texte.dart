// Die Texte des Schirms „Daten übernehmen" (#59 Teil 1) — Nutzertexte
// gehören in die Views, nicht in den Kern. Jede Aussage hier ist eine
// Zusage an Tim; sie steht in einer Datei, damit sie beim Ändern der
// Datenlage mitgeprüft wird (`CLAUDE.md`: „Keine Zusage stehen lassen, die
// nicht mehr stimmt").
import 'package:trainings_core/trainings_core.dart';

import '../design/formatierung.dart';
import '../health/health_types.dart' show datumAusTag;
import 'trainingsexport_uebernahme.dart';
import 'uebernahme_provider.dart';

/// Was der Schirm vor dem ersten Lauf sagt — und wie Tim zur Datei kommt.
const uebernahmeLeerText =
    'Noch nichts übernommen. Gib die Datei in der alten App aus '
    '(Mehr › Daten ausgeben › „Datei teilen“), sichere sie mit „In Dateien '
    'sichern“ und wähle sie hier.';

const uebernahmeLaeuftText = 'Die Datei wird eingelesen …';

/// Der Hinweis am Fuß — **in jedem Zustand** da. Jede Aussage stimmt für
/// `GymRepository.uebernimm` und `UmfaengeRepository.uebernimm`: nur
/// `INSERT`, nie `legeAb`, und die Datei selbst wird weder verändert noch
/// gelöscht.
///
/// Seit #498 stehen hier **zwei Zusagen zu den Umfängen**, die sonst
/// niemand erfährt — beide **einmal**, nicht je Feld:
///
/// 1. Übernommene Werte liegen mit `quelle = 'import'` in der Ablage; was
///    Tim später selbst einträgt, gewinnt, und zwar **maßweise**. Ohne den
///    Satz wüsste niemand, warum ein eingetippter Wert einen übernommenen
///    verdrängt — oder fürchtete, die Übernahme überschreibe etwas.
/// 2. Ein zweiter Lauf derselben Datei holt Korrekturen **nicht** nach
///    ([UmfangsImport.plan] schreibt nur dazu). Dieselbe Grenze wie bei den
///    Trainings; bei Maßen, die man nachmisst, fällt sie nur eher auf.
const uebernahmeUmfangText =
    'Übernommen werden die Gym-Trainings und die Umfänge der alten App. '
    'Nicht übernommen werden Tagestausche, angefangene Trainings, der '
    'Betrachtungszeitraum und der Dashboard-Import. Es wird nur '
    'dazugeschrieben: Was schon in der App steht, wird nie ersetzt oder '
    'gelöscht. Übernommene Umfänge gelten als übernommen, nicht als '
    'eingetragen — trägst du später selbst einen Wert ein, gilt deiner, und '
    'zwar für jedes Maß einzeln. Ein Training und eine Messung, die du in '
    'der alten App später geändert hast, bleiben hier auf dem Stand der '
    'ersten Übernahme: Ein zweiter Lauf derselben Datei holt Korrekturen '
    'nicht nach. Die Datei enthält Gesundheitsdaten; sie bleibt unverändert '
    'in „Dateien“ liegen.';

String uebernahmeMeldung(UebernahmeStand stand) => switch (stand) {
  UebernahmeLeer() => uebernahmeLeerText,
  UebernahmeLaeuft() => uebernahmeLaeuftText,
  UebernahmeFertig(:final ergebnis) => _fertigText(ergebnis),
  UebernahmeAbgelehnt(:final grund) => _abgelehntText(grund),
  UebernahmeGescheitert(:final fehler) =>
    'Die Übernahme konnte nicht abgeschlossen werden ($fehler). Es wurde '
        'nichts geschrieben. Du kannst es noch einmal versuchen.',
};

/// „an 2 Tagen" — der graue Zusatz hinter der Zahl der Einzelwerte.
///
/// Werte **und** Tage: Eine Messung mit dreizehn Maßen ist ein Tag und
/// dreizehn Werte. Nur die Werte zu nennen klänge nach dreizehn Messungen,
/// nur die Tage zu nennen verschwiege, wie viel dazukam.
String umfaengeTageText(int tage) =>
    'an ${tage == 1 ? '1 Tag' : '$tage Tagen'}';

String _fertigText(TrainingsexportUebernommen e) {
  final trainings = e.neu == 0
      ? null
      : '${e.neu == 1 ? '1 neues Training' : '${e.neu} neue Trainings'} mit '
            '${e.saetze} ${e.saetze == 1 ? 'Satz' : 'Sätzen'}';
  // Beides in **einem** Satz: Sonst meldete die Karte Umfänge, die Meldung
  // darüber aber nicht — und eine Datei, die nur Messungen trägt, bekäme
  // „nichts Neues" zu hören, während Werte geschrieben wurden (`01`).
  final umfaenge = e.umfaengeNeu == 0
      ? null
      : '${e.umfaengeNeu} '
            '${e.umfaengeNeu == 1 ? 'Umfangswert' : 'Umfangswerte'} '
            '${umfaengeTageText(e.umfaengeTage)}';

  final teile = [?trainings, ?umfaenge];
  if (teile.isEmpty) {
    return 'Gelesen, aber nichts Neues: Alles in der Datei war schon da, '
        'wurde nicht übernommen oder war nicht lesbar.';
  }
  return 'Übernommen: ${teile.join(' und ')}.';
}

String _abgelehntText(ExportRejection grund) {
  const ende = 'Es wurde nichts übernommen.';
  return switch (grund) {
    NotJson(:final detail) =>
      'Das ist keine lesbare Exportdatei: Der Inhalt ist kein gültiges JSON '
          '($detail). $ende',
    NotAnObject() =>
      'Das ist keine Exportdatei der alten App: Die Datei enthält JSON, aber '
          'keinen Export. $ende',
    WrongFormat(:final found) =>
      found == null
          ? 'Das ist keine Exportdatei der alten App: Es steht kein Format in '
                'der Datei. $ende'
          : 'Das ist keine Exportdatei der alten App: Als Format steht '
                '„$found“ in der Datei, gelesen wird „'
                '${TrainingsExport.formatName}“. $ende',
    UnsupportedVersion(:final found) =>
      'Diese Datei ist Fassung ${found ?? 'unbekannt'} des Exports, lesbar '
          'ist nur Fassung ${TrainingsExport.currentVersion}. Gib die Datei in '
          'der alten App neu aus — dort entsteht Fassung '
          '${TrainingsExport.currentVersion}. $ende',
    MalformedField(:final field) =>
      'Die Datei ist beschädigt: „$field“ fehlt oder hat die falsche Form. '
          '$ende',
  };
}

/// Eine Zeile je Sitzung, die nicht übernommen wurde.
String auslassungText(GymImportSkip skip) {
  final tag = Format.tag(kalendertag(skip.session.date));
  final workout = skip.session.workout?.label ?? 'ohne Workout';
  final grund = switch (skip.reason) {
    GymImportSkipReason.dayAndWorkoutTaken =>
      'an diesem Tag steht schon ein Training mit diesem Workout',
    GymImportSkipReason.duplicateInFile =>
      'in der Datei steht dasselbe Training mehrfach, eine Fassung wurde '
          'übernommen',
    GymImportSkipReason.alreadyPresent => 'schon da',
  };
  return '$tag · $workout — nicht übernommen: $grund';
}

/// Eine Zeile je Sitzung, die nicht lesbar war.
String nichtLesbarText(ExportSessionSkip skip) {
  final wer = skip.id == null
      ? 'Eintrag ${skip.index + 1}'
      : 'Eintrag ${skip.index + 1} (${skip.id})';
  final grund = switch (skip.reason) {
    ExportSkipReason.malformed =>
      '„${skip.detail}“ fehlt oder hat die falsche Form',
    ExportSkipReason.repsNotPositive =>
      'Wiederholungen unter 1 bei „${skip.detail}“',
    ExportSkipReason.duplicateExercise =>
      'die Übung „${skip.detail}“ steht doppelt',
  };
  return '$wer nicht lesbar: $grund. Das Training steht in der alten App '
      'weiter.';
}

/// Eine Zeile je Umfangswert, der nicht gelesen wurde.
///
/// **Kein Datum**, anders als bei den übersprungenen Trainings: Ein
/// [ExportMeasureSkip] trägt keines, und ein Eintrag ohne lesbares `date`
/// hat auch keins. Genannt wird die Stelle in der Datei — das ist, was
/// beim Nachsehen hilft.
String umfangNichtLesbarText(ExportMeasureSkip skip) {
  final wo = skip.source == 'dashboardImport.circumferences'
      ? 'Eintrag ${skip.index + 1} der Umfänge aus dem Dashboard-Import'
      : 'Eintrag ${skip.index + 1} der Umfänge';
  final roh = skip.measure;
  // Der deutsche Name, wo der Kern das Maß kennt — der Rohschlüssel sagt
  // Tim nichts.
  final mass = roh == null
      ? null
      : (Umfang.vonSchluessel(roh)?.deutsch ?? '„$roh“');

  return switch (skip.reason) {
    ExportMeasureSkipReason.malformed =>
      '$wo nicht lesbar: „${skip.detail}“ fehlt oder hat die falsche Form. '
          'Die Messung steht in der alten App weiter.',
    ExportMeasureSkipReason.notANumber =>
      '$wo · $mass — „${skip.detail}“ ist keine Zahl. Der Wert bleibt in der '
          'alten App.',
    ExportMeasureSkipReason.implausible =>
      '$wo · $mass — „${skip.detail}“ liegt außerhalb von '
          '${UmfangsEingabe.minCm.round()} bis '
          '${UmfangsEingabe.maxCm.round()} cm. Der Wert bleibt in der alten '
          'App.',
  };
}

/// Die Maße, die der Kern nicht kennt — **mit Namen**, nicht als Zahl: Eine
/// Zahl sagt nicht, welches Maß gefehlt hat, und nachsehen kann man es
/// hinterher nicht mehr.
String unbekannteMasseText(List<String> masse) =>
    'Dem Kern unbekannte Maße — ${masse.map((m) => '„$m“').join(', ')}. '
    'Diese Werte sind nicht übernommen; sie bleiben in der alten App.';

String unbekanntText(TrainingsexportUebernommen e) {
  final teile = [
    if (e.unbekannteUebungen.isNotEmpty)
      'Übungen: ${e.unbekannteUebungen.join(', ')}',
    if (e.unbekannteWorkouts.isNotEmpty)
      'Workouts: ${e.unbekannteWorkouts.join(', ')}',
  ];
  return 'Dem Katalog unbekannt — ${teile.join('; ')}. Die Sätze sind '
      'übernommen, tauchen aber in Muskelkarte und Fortschritt nicht auf; '
      'ein Training mit unbekanntem Workout steht ohne Workout da.';
}

String ungelesenText(Map<String, int> ungelesen) {
  // `circumferences` steht hier nicht: Seit #498 liest der Schritt die
  // Umfänge, und `ExportRead.unread` nennt sie nicht mehr. Ein Name für
  // einen Schlüssel, der nie kommt, behauptete das Gegenteil.
  const namen = {
    'swaps': 'Tagestausche',
    'drafts': 'angefangene Trainings',
    'dataWindow': 'Einträge zum Betrachtungszeitraum',
    'dashboardImport.sessions': 'Trainings aus dem Dashboard-Import',
  };
  final teile = [
    for (final e in ungelesen.entries) '${e.value} ${namen[e.key] ?? e.key}',
  ];
  final dashboard = (ungelesen['dashboardImport.sessions'] ?? 0) > 0;
  return 'Die Datei enthält mehr, als dieser Schritt liest: ${teile.join(', ')}. '
      '${dashboard ? 'Der Verlauf hier ist deshalb womöglich nicht '
                'vollständig. ' : ''}Das alles bleibt in der alten App.';
}

String zeitzoneText(String zone) =>
    'Die Datei nennt die Zeitzone „$zone“. Die Tage der Trainings sind nach '
    'Berliner Zeit gerechnet.';

/// Ein ISO-Tagesschlüssel als „14.01.2099“.
String _tag(String iso) => Format.tag(kalendertag(datumAusTag(iso)));

/// Sätze, Zeitraum (Berliner Tage) und Erzeugung der Datei — Beiwerk zur
/// Karte, nur nach einem gelaufenen Lauf.
String berichtZeile(TrainingsexportUebernommen e) {
  final erster = e.ersterTag;
  final letzter = e.letzterTag;
  final zeitraum = erster == null || letzter == null
      ? 'keine neuen Trainings'
      : erster == letzter
      ? _tag(erster)
      : '${_tag(erster)} bis '
            '${_tag(letzter)}';
  final erzeugt = Format.tag(kalendertag(e.erzeugtAm));
  return '${e.saetze} Sätze · $zeitraum · Datei erzeugt $erzeugt';
}
