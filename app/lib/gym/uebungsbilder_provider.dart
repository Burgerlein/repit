import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart' show ExerciseLibrary;

import 'uebungsbilder.dart';

/// Die Bewegungsbilder aller Katalogübungen (#38), **einmal beim Start
/// geladen** und danach nur noch nachgeschlagen.
///
/// Wirft ohne Override, wie `appCacheProvider`: Nur `main()` setzt den Wert
/// ([ladeUebungsbilder]); jeder Test überschreibt ihn selbst.
///
/// **Der Provider ist synchron, und das ist die Antwort auf „lädt noch" oder
/// „gibt es nicht".** Es gibt keinen Zustand dazwischen: Zum Zeitpunkt, an
/// dem ein Schirm den Provider liest, ist das Asset schon gelesen.
/// `Uebungsbilder.fuer(id) == null` heißt deshalb endgültig „diese Übung hat
/// kein Bild", nie „noch nicht da". Was noch laden kann, ist die Bilddatei
/// selbst — dafür steht der Platz im Schirm von Anfang an (siehe
/// `GymBewegungsbild`).
final uebungsbilderProvider = Provider<Uebungsbilder>(
  (ref) => throw UnimplementedError(
    'uebungsbilderProvider muss in main.dart mit dem Ergebnis von '
    'ladeUebungsbilder() überschrieben werden.',
  ),
);

/// Ob mindestens eine Übung der Bibliothek **kein** Bewegungsbild hat — die
/// „gemischte Lage" (#551, Nachtrag 17 Nr. 1): Nur dann zeigt die Auswahl
/// das Abspiel-Icon, denn ein Icon, das an jeder der 581 Zeilen steht,
/// unterscheidet nichts. Heute haben alle eines; das Icon ist **latent** und
/// erscheint erst, wenn Übungen ohne Bild dazukommen (`x-`-Ergänzungen).
///
/// **Einmal gerechnet und gehalten** (Hausregel 2) — die eine Stelle, die
/// die Lage kennt; die Zeilen der Auswahl fragen nur noch `fuer(id)`.
final uebungsbilderGemischtProvider = Provider<bool>((ref) {
  final bilder = ref.watch(uebungsbilderProvider);
  for (final id in ExerciseLibrary.all.keys) {
    if (bilder.fuer(id) == null) return true;
  }
  return false;
});

/// Liest die Bilder aus dem Bündel. Ist das Asset nicht lesbar oder passt es
/// nicht zur App (`Uebungsbilder.parse` wirft), bleibt **jede Übung ohne
/// Bild benutzbar**: Die Anleitung steht ohne das Bild vollständig da, und
/// ein Start, der daran scheitert, wäre schlimmer als das fehlende Bild.
///
/// Das ist die **eine** Stelle, die den Fehler fängt; er wird gemeldet, nicht
/// verschluckt.
Future<Uebungsbilder> ladeUebungsbilder(AssetBundle bundle) async {
  try {
    return await Uebungsbilder.laden(bundle);
  } catch (fehler, stapel) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: fehler,
        stack: stapel,
        library: 'uebungsbilder',
        context: ErrorDescription(
          'beim Laden der Bewegungsbilder — die App startet ohne sie',
        ),
      ),
    );
    return Uebungsbilder.leer;
  }
}
