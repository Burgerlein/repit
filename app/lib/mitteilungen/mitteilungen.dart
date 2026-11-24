// Die Naht zu den lokalen Mitteilungen (#593).
//
// **Nur lokale Mitteilungen, kein Push** — das kostenlose Personal Team
// vergibt die Push-Capability nicht (`CLAUDE.md`). Die App plant die
// Mitteilung auf dem Gerät; es gibt keinen Server.
//
// Aufbau wie `HealthReading`: ein schmales Protokoll, eine
// Mock-Fassung für Tests, ein Provider dazwischen. Ohne das liefe
// `flutter test` nicht mehr nativ, sobald eine Plattform-Abhängigkeit
// im Spiel ist — und genau das ist das Kriterium, das `dart test` und
// `flutter test` zum Standardweg macht.
//
// **Die echte Fassung über `flutter_local_notifications` ist noch nicht
// angeschlossen.** Diese Datei ist die Stelle, an der sie andockt; bis
// dahin läuft die App mit [MitteilungenAus], und jeder Schirm, der
// Erinnerungen anbietet, sagt ehrlich, dass keine ankommt.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Eine geplante Mitteilung.
///
/// [kennung] ist der Schlüssel, unter dem sie zurückgezogen wird. Wer
/// eine Erinnerung ändert, zieht die alte unter derselben Kennung
/// zurück — sonst klingelt es zweimal. Dieselbe Regel wie bei der
/// Gym-Pause (`gymPauseMitteilungKennung`).
@immutable
class GeplanteMitteilung {
  const GeplanteMitteilung({
    required this.kennung,
    required this.titel,
    required this.text,
    required this.wann,
    this.taeglich = false,
  });

  final String kennung;
  final String titel;
  final String text;

  /// Der Zeitpunkt in UTC. **Kein Ereignisdatum im Quelltext** — er
  /// kommt immer aus den Daten (`CLAUDE.md`).
  final DateTime wann;

  /// Wiederholt sich täglich zur selben Uhrzeit.
  final bool taeglich;

  @override
  bool operator ==(Object other) =>
      other is GeplanteMitteilung &&
      other.kennung == kennung &&
      other.titel == titel &&
      other.text == text &&
      other.wann == wann &&
      other.taeglich == taeglich;

  @override
  int get hashCode => Object.hash(kennung, titel, text, wann, taeglich);

  @override
  String toString() =>
      'GeplanteMitteilung($kennung, ${wann.toIso8601String()}'
      '${taeglich ? ', täglich' : ''})';
}

/// Ob die Nutzerin Mitteilungen erlaubt hat.
///
/// **Anders als bei HealthKit verrät iOS das ehrlich** — der Schirm
/// kann „nicht erlaubt" also sagen, statt es zu raten. Genau deshalb
/// gibt es hier drei Werte und nicht zwei.
enum MitteilungsFreigabe {
  /// Noch nicht gefragt.
  offen,

  /// Erlaubt.
  erteilt,

  /// Abgelehnt oder in den Einstellungen abgeschaltet.
  verweigert,
}

/// Was eine Mitteilungsschicht können muss.
abstract interface class Mitteilungen {
  Future<MitteilungsFreigabe> freigabe();

  /// Fragt einmal nach. Ist schon entschieden, kommt die Entscheidung
  /// zurück, ohne zu fragen.
  Future<MitteilungsFreigabe> frageFreigabe();

  /// Plant [mitteilung] und **ersetzt** eine bereits geplante mit
  /// derselben Kennung.
  Future<void> plane(GeplanteMitteilung mitteilung);

  /// Zieht die Mitteilung mit dieser Kennung zurück. Gibt es keine,
  /// passiert nichts.
  Future<void> ziehZurueck(String kennung);

  /// Zieht alle Mitteilungen zurück, deren Kennung mit [praefix]
  /// beginnt.
  ///
  /// Dafür tragen die Kennungen einen Punkt im Namen (`zyklus.periode`):
  /// Wenn sich die Vorhersage ändert, muss alles abgeräumt werden, was
  /// an ihr hing — sonst kommt eine Mitteilung zu einem Tag, der nicht
  /// mehr gilt.
  Future<void> ziehGruppeZurueck(String praefix);

  /// Was gerade geplant ist. Für Prüfungen und für den Schirm.
  Future<List<GeplanteMitteilung>> geplante();
}

/// Die Fassung, mit der die App heute läuft: Sie nimmt alles an und
/// plant nichts.
///
/// **Sie behauptet keine Freigabe.** [freigabe] gibt
/// [MitteilungsFreigabe.verweigert] zurück, damit die Schirme sagen,
/// dass keine Erinnerung ankommt — eine Schicht, die stillschweigend
/// nichts tut, wäre schlimmer als gar keine.
class MitteilungenAus implements Mitteilungen {
  const MitteilungenAus();

  @override
  Future<MitteilungsFreigabe> freigabe() async =>
      MitteilungsFreigabe.verweigert;

  @override
  Future<MitteilungsFreigabe> frageFreigabe() async =>
      MitteilungsFreigabe.verweigert;

  @override
  Future<void> plane(GeplanteMitteilung mitteilung) async {}

  @override
  Future<void> ziehZurueck(String kennung) async {}

  @override
  Future<void> ziehGruppeZurueck(String praefix) async {}

  @override
  Future<List<GeplanteMitteilung>> geplante() async => const [];
}

/// Eine Fassung, die sich merkt, was geplant wurde — für Tests und für
/// den Simulator.
class MitteilungenImSpeicher implements Mitteilungen {
  MitteilungenImSpeicher({this.stand = MitteilungsFreigabe.erteilt});

  /// Der Freigabestand, den diese Fassung vorgibt — in Tests gesetzt,
  /// um den Zustand „Mitteilungen nicht erlaubt“ zu zeigen.
  MitteilungsFreigabe stand;
  final Map<String, GeplanteMitteilung> _geplant = {};

  @override
  Future<MitteilungsFreigabe> freigabe() async => stand;

  @override
  Future<MitteilungsFreigabe> frageFreigabe() async {
    if (stand == MitteilungsFreigabe.offen) {
      stand = MitteilungsFreigabe.erteilt;
    }
    return stand;
  }

  @override
  Future<void> plane(GeplanteMitteilung mitteilung) async {
    _geplant[mitteilung.kennung] = mitteilung;
  }

  @override
  Future<void> ziehZurueck(String kennung) async {
    _geplant.remove(kennung);
  }

  @override
  Future<void> ziehGruppeZurueck(String praefix) async {
    _geplant.removeWhere((kennung, _) => kennung.startsWith(praefix));
  }

  @override
  Future<List<GeplanteMitteilung>> geplante() async =>
      _geplant.values.toList()..sort((a, b) => a.wann.compareTo(b.wann));
}

/// Die Schicht, die die App benutzt.
///
/// Überschrieben wird sie in `main.dart`, sobald die echte Fassung
/// steht — und in Tests durch [MitteilungenImSpeicher].
final mitteilungenProvider = Provider<Mitteilungen>(
  (ref) => const MitteilungenAus(),
);
