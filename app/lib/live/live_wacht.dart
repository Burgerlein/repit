// Die Verdrahtung der Live-Aktivität (#369, Task 7 des Plans
// `docs/superpowers/plans/2026-11-05-live-aktivitaet.md`, Spec
// `docs/superpowers/specs/2026-11-05-live-aktivitaet-design.md`, „Die
// Dart-Seite → Verdrahtung"): Start, Rückkehr, Buchung, Link.
//
// Verhalten vorgegeben durch `app/test/live/live_wacht_test.dart` — diese
// Datei darf die Tests ausführen, aber nicht verändern (`CLAUDE.md`).
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ernaehrung/kamera_seite.dart';
import '../shell/router.dart';
import 'live_anzeige.dart';
import 'live_provider.dart';
import 'live_types.dart';

/// Hängt die Live-Aktivität an die App: Was [liveSollProvider] sagt, geht
/// über [LiveSteuerung] an iOS, beim Start, nach jeder Buchung und bei
/// jeder Rückkehr in den Vordergrund (V6). Ein Tipp auf die Karte öffnet
/// „Mahlzeit eintragen" auf dem Stapel des gerade gewählten Tabs.
///
/// Sitzt in `main.dart` **innerhalb** des `ProviderScope` und **oberhalb**
/// der `CupertinoApp`, neben `Tageswacht`: Sie lebt so lange wie die App,
/// nicht so lange wie ein Schirm. Deshalb braucht sie den [router] aus
/// `main()` — dieselbe Instanz, die `RootView` bekommt.
///
/// **Start und Änderung gehen getrennte Wege**, weil Riverpod 3.4.3 am
/// `ref.listen` eines Widgets kein `fireImmediately` mehr kennt
/// (`flutter_riverpod/lib/src/core/consumer.dart`, „we wouldn't want to
/// call the listener on every rebuild"), und `listenManual` gehörte in
/// `initState` — `ref` steht hier nur in `build` (`CLAUDE.md`):
///
/// - **Änderungen** kommen über `ref.listen`. Riverpod meldet nur ein
///   ungleiches Soll (`LiveSoll` hat `==`), und ein Neuaufbau meldet die
///   Abonnierung neu an, ohne zu feuern (Review Focus 4). Wichtig ist der
///   Weg, nicht nur das Ergebnis: Der Hörer hängt an Riverpods eigenem
///   Takt, nicht an einem Bild. Ein Weg über den Neuaufbau dieser Hülle
///   wartete auf das nächste Bild, und im Hintergrund kommt keins: Im
///   Simulator stand eine Buchung, die nach dem Sperren fertig wurde, erst
///   nach der Rückkehr auf der Karte. Ob iOS den Prozess nach dem Sperren
///   überhaupt weiterlaufen lässt, ist eine zweite Frage — im zweiten Lauf
///   tat es das nicht, dann holt die Rückkehr es nach (V6).
/// - **Den Start** übernimmt [_LiveLebenszyklus] in `initState`, mit dem
///   Soll vom ersten Bauen. Ist es noch `null` (Einträge laden), tut `nimm`
///   nichts, und der erste echte Wert kommt als Änderung (V10).
class LiveWacht extends ConsumerWidget {
  const LiveWacht({super.key, required this.router, required this.child});

  /// Derselbe Router wie in `RootView` — die Kamera geht auf dessen
  /// gewählten Tab.
  final AppRouter router;

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.notifier` beobachtet nicht den Zustand, es hält die Steuerung am
    // Leben (wie in `Tageswacht`). Ihr Merker „nächstes Zeigen frisch" muss
    // über die ganze Laufzeit derselbe sein.
    final steuerung = ref.watch(liveSteuerungProvider.notifier);
    final anzeige = ref.watch(liveAnzeigeProvider);
    // `watch` nur, damit es ein Soll für den Start gibt — danach liest es
    // niemand mehr. Der Neuaufbau, den es auslöst, trifft nur diese Hülle:
    // [child] ist dieselbe Instanz und bleibt stehen.
    final anfang = ref.watch(liveSollProvider);
    ref.listen<LiveSoll?>(
      liveSollProvider,
      (_, neu) => _sicher(steuerung.nimm(neu)),
    );

    return _LiveLebenszyklus(
      anfang: anfang,
      nimm: steuerung.nimm,
      beiRueckkehr: steuerung.beiRueckkehr,
      holeLink: steuerung.holeLink,
      linkDa: anzeige.linkDa,
      // Der Esstag wird **beim Öffnen** gelesen, nicht beim Bauen: Nach
      // einer Rückkehr über 04:00 hat `beiRueckkehr` ihn gerade erst
      // vorgerückt, und ein beim letzten Bauen festgehaltener Wert buchte
      // auf den Vortag. Der Aufruf kommt nur aus einem lebenden State
      // (`mounted` wird dort geprüft).
      oeffneEintragen: () =>
          oeffneKamera(router, tagesSchluessel: ref.read(esstagProvider)),
      child: child,
    );
  }
}

/// Der Lebenszyklus der Live-Aktivität, ohne Riverpod: Er bekommt das Soll
/// vom Start und gebundene Methoden gereicht, wie `_Lebenszyklus` in
/// `Tageswacht`.
class _LiveLebenszyklus extends StatefulWidget {
  const _LiveLebenszyklus({
    required this.anfang,
    required this.nimm,
    required this.beiRueckkehr,
    required this.holeLink,
    required this.linkDa,
    required this.oeffneEintragen,
    required this.child,
  });

  /// Das Soll beim ersten Bauen. Spätere Werte liest der State nicht —
  /// die kommen über `ref.listen` in [LiveWacht.build].
  final LiveSoll? anfang;
  final Future<void> Function(LiveSoll? soll) nimm;
  final Future<void> Function() beiRueckkehr;
  final Future<LiveZiel?> Function() holeLink;
  final Stream<void> linkDa;
  final VoidCallback oeffneEintragen;
  final Widget child;

  @override
  State<_LiveLebenszyklus> createState() => _LiveLebenszyklusState();
}

class _LiveLebenszyklusState extends State<_LiveLebenszyklus>
    with WidgetsBindingObserver {
  StreamSubscription<void>? _linkAbo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _linkAbo = widget.linkDa.listen((_) => _holeLink());
    // Steht das Soll schon beim ersten Bauen fest, geht es jetzt hinaus;
    // ist es noch `null` (Einträge laden), tut `nimm` nichts (V10).
    _sicher(widget.nimm(widget.anfang));
    // Kaltstart über die Karte: Der Link war vor der Engine da. Gefragt
    // wird nach dem ersten Bild — vorher hat `RootView` noch keinen
    // Navigator, auf den die Kamera könnte.
    WidgetsBinding.instance.addPostFrameCallback((_) => _holeLink());
  }

  @override
  void didUpdateWidget(_LiveLebenszyklus alt) {
    super.didUpdateWidget(alt);
    if (!identical(alt.linkDa, widget.linkDa)) {
      _linkAbo?.cancel();
      _linkAbo = widget.linkDa.listen((_) => _holeLink());
    }
  }

  @override
  void dispose() {
    _linkAbo?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Nur `resumed`, aus demselben Grund wie in `Tageswacht`: Jeder Weg
  /// zurück nach vorn endet dort, `inactive` und `hidden` laufen auch
  /// ohne Rückkehr durch.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _sicher(() async {
      await widget.beiRueckkehr();
      await _holeLink();
    }());
  }

  /// Holt den Link ab — der Puffer gibt ihn genau einmal her — und öffnet
  /// das Ziel. Zwei Ereignisse kurz nacheinander öffnen deshalb höchstens
  /// eine Kamera, und `oeffneKamera` lässt ohnehin keine zweite zu (#326).
  Future<void> _holeLink() => _sicher(() async {
    final ziel = await widget.holeLink();
    if (!mounted) return;
    switch (ziel) {
      case LiveZiel.mahlzeitEintragen:
        widget.oeffneEintragen();
      case null:
        break;
    }
  }());

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Eine Karte, die nicht aufgeht, darf weder Buchen noch Öffnen aufhalten
/// (Spec, „`zeige` wirft nicht"). `zeige` fängt selbst; `beendeAlle` und
/// `nimmLink` lassen eine `PlatformException` durch, und die endet hier
/// statt als unbehandelter Fehler in der Zone.
Future<void> _sicher(Future<void> arbeit) async {
  try {
    await arbeit;
  } on Object catch (fehler, stapel) {
    debugPrint('Live-Aktivität: $fehler\n$stapel');
  }
}
