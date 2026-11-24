// Der Anstoß für `HeutigerTagNotifier.pruefeTageswechsel()` (#124, zu #90).
//
// `pruefeTageswechsel()` war gebaut und geprüft, aber niemand rief es auf:
// Lag die App über Mitternacht im Hintergrund und kam wieder nach vorn,
// rechnete sie weiter auf dem Vortag — „Heute" war gestern, der
// Erholungs-Schirm rechnete gegen die falsche Nacht, und erst ein Neustart
// rückte die Sache zurecht. Diese Datei ist der fehlende Aufrufer.
//
// Verhalten vorgegeben durch `app/test/shell/tageswacht_test.dart` — diese
// Datei darf die Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer
// Tests schreibt, schreibt nicht die Implementierung"). Die Wachbelege beim
// Aufbau und bei der Rückkehr (#455) gibt `app/test/tag/laufender_tag_test.dart`
// vor, ebenso unverändert.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/wach_belege.dart';
import '../health/health_provider.dart';
import '../tag/laufender_tag_provider.dart';

/// Hängt [child] an den App-Lebenszyklus: Kommt die App nach vorn, wird
/// geprüft, ob inzwischen ein Berliner Kalendertag vergangen ist — **und
/// ob der letzte Lauf gegen HealthKit lange genug her ist** (#309).
///
/// **Zwei Anstöße, ein Beobachter.** Der zweite kam am 04.11.2026 dazu:
/// `pruefeTageswechsel()` tut nur etwas, wenn sich der *Tag* geändert
/// hat, also las die App am selben Tag überhaupt nicht nach. Tim sah um
/// 09:04 den Schlafstand von 06:45 — 6:18 h statt 7:53 h. Ein zweiter
/// `WidgetsBindingObserver` daneben hätte dieselbe Rückkehr zweimal
/// gemeldet; die Stelle, die `resumed` schon beobachtet, ist diese hier.
///
/// Sitzt in `main.dart` **innerhalb** des `ProviderScope` und umschließt die
/// ganze App — nicht in `RootView`: Was so lange leben soll wie die App,
/// gehört nicht in einen Schirm mitten im Tab-Gerüst, und `RootView` wird
/// von einer Reihe Widget-Tests ohne `ProviderScope` gepumpt.
///
/// **Warum nicht im Notifier selbst**, wo `ref` ohnehin erlaubt wäre: Dort
/// steht ausdrücklich „Wer das aufruft, entscheidet die Widget-Schicht". Ein
/// `WidgetsBinding`-Beobachter in `health_provider.dart` zöge die
/// Widget-Schicht in die Datenschicht und machte den Notifier in einem
/// reinen `ProviderContainer`-Test vom Binding abhängig.
///
/// **Der Start braucht keinen eigenen Ruf.** `HeutigerTagNotifier.build()`
/// liest die Uhr beim ersten Zugriff; indem diese Hülle den Provider schon
/// beim Aufbau des Baums anfasst, steht der Tag fest, bevor ihn ein Schirm
/// liest. Ein zusätzliches `pruefeTageswechsel()` in `initState` fände
/// per Konstruktion nie etwas.
class Tageswacht extends ConsumerWidget {
  const Tageswacht({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `ref` nur hier in `build` (Hausregel, Spec 5.4 Punkt 3) — der
    // Lebenszyklus-Beobachter unten bekommt die fertig gebundene Methode
    // gereicht und kennt Riverpod nicht.
    //
    // `.notifier` beobachtet **nicht** den Zustand: Diese Hülle baut beim
    // Tageswechsel nicht neu (sie hätte nichts anderes zu zeigen), und das
    // wäre bei einer Hülle um die ganze App auch das Letzte, was man will.
    // Was `watch` hier leistet, ist das Gegenteil von Arbeit: Es hält den
    // Provider am Leben, solange die App steht, statt ihn beim ersten
    // Zugriff irgendeines Schirms entstehen zu lassen.
    final heutigerTag = ref.watch(heutigerTagProvider.notifier);
    final nachlauf = ref.watch(nachlaufProvider.notifier);
    final wachbelege = ref.watch(wachbelegProvider.notifier);
    // **Ein Wachbeleg `oeffnen` beim Aufbau und bei jeder Rückkehr** (V13,
    // #455): Wer die App öffnet, ist wach. Der Beleg lässt den laufenden
    // Tag nachsehen; bei der Rückkehr erst nach `pruefeTageswechsel()`,
    // damit der Kalendertag schon steht, wenn der laufende Tag rechnet.
    void merkeOeffnen() =>
        unawaited(_sicher(wachbelege.merke(WachArt.oeffnen)));
    return _Lebenszyklus(
      beimAufbau: merkeOeffnen,
      // **Der Nachlauf zuerst, der Tageswechsel danach** — die Reihenfolge
      // ist Teil der Abmachung, nicht Geschmack (`NachlaufNotifier`).
      // `pruefeNachlauf()` hält sich heraus, wenn inzwischen ein
      // Kalendertag vergangen ist: Dann rechnet gleich ohnehin alles neu,
      // und ein Anstoß von ihm wäre ein zweiter neben dem, der sowieso
      // kommt. Diese Entscheidung trifft er anhand des Tages, der *noch*
      // gilt — würde `pruefeTageswechsel()` vorher laufen, fände er den
      // schon nachgerückten vor und könnte den Fall nicht mehr erkennen.
      aufRueckkehr: () {
        nachlauf.pruefeNachlauf();
        heutigerTag.pruefeTageswechsel();
        merkeOeffnen();
      },
      child: child,
    );
  }
}

/// Ruft [aufRueckkehr], sobald die App wieder nach vorn kommt.
///
/// **Nur `AppLifecycleState.resumed`.** Das ist der einzige Zustand, der
/// „die App ist vorn und nimmt wieder Eingaben entgegen" bedeutet.
/// `inactive` und `hidden` sind Durchgangszustände: Auf iOS laufen sie auch
/// dann durch, wenn die App gar nicht weg war — Kontrollzentrum
/// herunterziehen, App-Umschalter antippen, ein Anruf- oder
/// Mitteilungsbanner. Dort zu prüfen, brächte keinen Fall dazu, denn
/// **jeder** Weg zurück nach vorn endet bei `resumed`; es brächte nur Rufe,
/// bei denen niemand zurückgekommen ist.
///
/// Ein Ruf, der nichts findet, kostet dabei fast nichts:
/// `pruefeTageswechsel()` liest die Uhr, rechnet eine Tagesgrenze aus
/// (`BerlinCalendar.startOfDay`, reine Arithmetik) und vergleicht,
/// `pruefeNachlauf()` liest dazu den Stand der Lade-Provider, die es
/// schon gibt. Trifft keine der Bedingungen zu, wird **nicht**
/// zugewiesen — kein neuer Zustand, keine Benachrichtigung, nichts, was
/// neu rechnet. Ein Wächter davor wäre teurer als der Ruf.
class _Lebenszyklus extends StatefulWidget {
  const _Lebenszyklus({
    required this.beimAufbau,
    required this.aufRueckkehr,
    required this.child,
  });

  /// Einmal, wenn die Hülle entsteht — beim Kaltstart.
  final VoidCallback beimAufbau;
  final VoidCallback aufRueckkehr;
  final Widget child;

  @override
  State<_Lebenszyklus> createState() => _LebenszyklusState();
}

class _LebenszyklusState extends State<_Lebenszyklus>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.beimAufbau();
  }

  @override
  void dispose() {
    // Kein `ref` hier — der Beobachter kennt nur einen Callback. Genau
    // deshalb liegt die Riverpod-Seite eine Ebene höher: `ref` in
    // `State.dispose` ist die Stelle, an der `avoid_ref_inside_state_dispose`
    // in diesem Projekt schon einmal zugeschlagen hat.
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.aufRueckkehr();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Ein Wachbeleg, der nicht geschrieben werden kann, hält die App nicht
/// auf: Ohne ihn wird der Tag nicht verlängert, und das ist die vorsichtige
/// Seite (V11). Gemeldet wird er im Log.
Future<void> _sicher(Future<void> arbeit) async {
  try {
    await arbeit;
  } on Object catch (fehler, stapel) {
    debugPrint('Wachbeleg: $fehler\n$stapel');
  }
}
