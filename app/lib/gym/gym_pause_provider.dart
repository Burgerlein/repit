// Die Pausenuhr zwischen zwei Sätzen (#78) — Dart-Entsprechung von
// `Sources/Features/Gym/RestTimer.swift`, ohne die Mitteilung.
//
// **Sie merkt sich den Startzeitpunkt, nicht die abgelaufenen Sekunden**
// (`RestTimer.swift:9–12`, und das ist die wichtigste Zeile der Datei): Ein
// hochgezählter Stand stünde still, sobald die App in den Hintergrund geht,
// und zeigte danach eine zu kurze Pause an. Der Takt unten treibt nur die
// Ansicht; gerechnet wird immer gegen die Uhr
// (`verstrichen = jetzt − gestartetUm`).
//
// **Der Takt hat einen eigenen, schmalen Provider** (Spec 7.2). Ein
// 500-ms-Takt, an dem der Entwurf des Trainings hinge, zeichnete zweimal je
// Sekunde sieben Übungskarten neu — Fehler `03` mit Ansage. Den Takt liest
// ausschließlich [gymPauseAnzeigeProvider], und den liest ausschließlich
// die Pausenzeile.
//
// **Die Uhr gehört zum Training, nicht zur Übung** (`gym-log.js:86–88`): Es
// gibt genau eine, und sie steht in der Übung, in der man gerade ist
// (`GymLogEntwurf.ersteOffeneUebung`). Deshalb ist sie nicht je Workout
// angelegt und hängt nicht am Entwurf.
//
// **Die Mitteilung „Pause vorbei" fehlt hier mit Absicht** (Spec 7.3): Sie
// ist eine lokale Benachrichtigung und braucht eine eigene schmale Schicht
// nach dem Muster von `HealthReading` — sonst läuft `flutter test` nicht
// mehr nativ. Sie hängt sich an [GymPauseNotifier.starte] (planen) und
// [GymPauseNotifier.stoppe] (zurückziehen); die Texte stehen schon in
// `gym_log_texte.dart`.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../health/health_provider.dart' show clockProvider;

/// Eine laufende Pause.
///
/// **Werttyp mit [==] und [hashCode] über alle Felder** (Fehler `03`).
@immutable
class GymPause {
  const GymPause({required this.gestartetUm, required this.zielSekunden});

  /// Der Startzeitpunkt, UTC — **nicht** die verstrichenen Sekunden.
  final DateTime gestartetUm;

  /// Die empfohlene Pause in Sekunden (`RestGuidance.seconds`).
  final int zielSekunden;

  @override
  bool operator ==(Object other) =>
      other is GymPause &&
      other.gestartetUm == gestartetUm &&
      other.zielSekunden == zielSekunden;

  @override
  int get hashCode => Object.hash(gestartetUm, zielSekunden);

  @override
  String toString() => 'GymPause($gestartetUm, Ziel $zielSekunden s)';
}

/// Die laufende Pause, `null` wenn keine läuft.
///
/// Ändert sich nur bei Start und Stopp — **nicht im Takt**.
final gymPauseProvider = NotifierProvider<GymPauseNotifier, GymPause?>(
  GymPauseNotifier.new,
);

class GymPauseNotifier extends Notifier<GymPause?> {
  @override
  GymPause? build() => null;

  /// Startet die Pause mit der empfohlenen Zeit der Übung
  /// (`RestGuidance.seconds`: Zeitübung 45 s, `repHigh ≤ 10` 150 s,
  /// `≤ 15` 90 s, sonst 60 s). Eine laufende Pause beginnt von vorn.
  void starte(Exercise uebung) {
    state = GymPause(
      gestartetUm: ref.read(clockProvider)().toUtc(),
      zielSekunden: RestGuidance.seconds(uebung),
    );
  }

  /// Hält die Pause an. Läuft keine, passiert nichts.
  void stoppe() {
    if (state != null) state = null;
  }
}

/// Wie oft die Anzeige neu rechnet: **500 ms** (Spec 7.1). `null` schaltet
/// den Takt ab.
///
/// **Der Schalter für Tests:** Ein laufender `Timer.periodic` lässt einen
/// Widget-Test mit „A Timer is still pending" enden. Ein Test überschreibt
/// diesen Provider mit `null` und stellt die Uhr über [clockProvider].
final gymTaktDauerProvider = Provider<Duration?>(
  (ref) => const Duration(milliseconds: 500),
);

/// Der Takt: eine Zahl, die hochzählt. Ihr Wert ist gleichgültig — sie
/// existiert, damit [gymPauseAnzeigeProvider] neu rechnet.
///
/// `autoDispose`: Der Takt läuft nur, solange jemand zuhört, also nur,
/// solange eine Pause läuft **und** die Pausenzeile auf dem Schirm steht.
final gymTaktProvider = NotifierProvider.autoDispose<GymTaktNotifier, int>(
  GymTaktNotifier.new,
);

class GymTaktNotifier extends Notifier<int> {
  @override
  int build() {
    final dauer = ref.watch(gymTaktDauerProvider);
    if (dauer != null) {
      final timer = Timer.periodic(dauer, (_) => state++);
      ref.onDispose(timer.cancel);
    }
    return 0;
  }
}

/// Was die Pausenzeile zeigt: wie lange die Pause schon läuft und wie lang
/// sie sein soll.
///
/// **Werttyp mit [==] und [hashCode] über alle Felder** (Fehler `03`).
/// Der Provider rechnet alle 500 ms; die Zeile zeichnet nur neu, wenn die
/// Sekunde gesprungen ist.
@immutable
class GymPauseAnzeige {
  const GymPauseAnzeige({required this.verstrichen, required this.ziel});

  /// Ganze Sekunden seit dem Start, nie negativ.
  final int verstrichen;

  final int ziel;

  /// Ob die Pause um ist — dann zählt die Uhr hoch statt herunter.
  bool get vorbei => verstrichen >= ziel;

  /// Die Zahl, die dasteht: **vor Ablauf die Restzeit, danach die Zeit über
  /// der Pause** — „wie lange stehe ich hier schon" ist dann die
  /// interessantere Zahl (`RestTimer.label`).
  int get sekunden => vorbei ? verstrichen - ziel : ziel - verstrichen;

  @override
  bool operator ==(Object other) =>
      other is GymPauseAnzeige &&
      other.verstrichen == verstrichen &&
      other.ziel == ziel;

  @override
  int get hashCode => Object.hash(verstrichen, ziel);

  @override
  String toString() => 'GymPauseAnzeige($verstrichen / $ziel s)';
}

/// Die Anzeige der Pause, `null` wenn keine läuft. **Das ist der einzige
/// Provider, an dem der Takt hängt.**
///
/// Gerechnet wird gegen die Uhr, nicht gegen den Takt: Wer die Uhr um 90 s
/// vorstellt, ohne dass ein Takt lief, sieht beim nächsten Lesen 90 s
/// verstrichen — das ist der Hintergrundfall, und er geht ohne Gerät.
///
/// **Der Takt wird erst abonniert, wenn eine Pause läuft.** Ohne Pause
/// tickt nichts.
final gymPauseAnzeigeProvider = Provider.autoDispose<GymPauseAnzeige?>((ref) {
  final pause = ref.watch(gymPauseProvider);
  if (pause == null) return null;
  ref.watch(gymTaktProvider);
  final jetzt = ref.watch(clockProvider)();
  final verstrichen = jetzt.difference(pause.gestartetUm).inSeconds;
  return GymPauseAnzeige(
    verstrichen: verstrichen < 0 ? 0 : verstrichen,
    ziel: pause.zielSekunden,
  );
});
