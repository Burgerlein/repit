// Der Kanal zur Live-Aktivität hinter einem Protokoll (#367, Task 5 des
// Plans `docs/superpowers/plans/2026-11-05-live-aktivitaet.md`, Spec
// `docs/superpowers/specs/2026-11-05-live-aktivitaet-design.md`, „Kanal
// hinter einem Protokoll").
//
// API und Vertrag sind durch `app/test/live/live_anzeige_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf). Diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`).
//
// **Views rufen nie den Kanal.** Der einzige Rufer ist `LiveSteuerung` in
// `live_provider.dart`; alles andere geht über [liveAnzeigeProvider].
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import 'live_types.dart';

/// Der Name des Kanals, identisch zur Swift-Seite
/// (`app/ios/Runner/LiveChannel.swift`).
const liveKanalName = 'de.rosenbach.repit/live';

/// Was die App von der Live-Aktivität braucht — und nicht mehr.
///
/// Die Swift-Seite entscheidet keine Fassung, sie stellt nur sicher, dass
/// genau eine Aktivität existiert. Welche, entscheidet `waehleFassung` im
/// Kern.
abstract interface class LiveAnzeige {
  /// Zeigt [karte]. [frisch] verlangt einen Neustart statt eines Updates
  /// (V6). **Wirft nicht** — jeder Ausgang ist ein [LiveErgebnis].
  Future<LiveErgebnis> zeige(EssenKarte karte, {required bool frisch});

  /// Beendet jede Aktivität der App.
  Future<void> beendeAlle();

  /// Holt den zuletzt angekommenen Link ab und **leert** ihn dabei. Ein
  /// Link wird so genau einmal abgeholt, egal wie oft gefragt wird.
  Future<LiveZiel?> nimmLink();

  /// Ein Ereignis je angekommenem Link, während die Engine läuft. Wer es
  /// hört, antwortet mit [nimmLink].
  Stream<void> get linkDa;
}

/// Spricht den Kanal [liveKanalName].
class KanalLiveAnzeige implements LiveAnzeige {
  KanalLiveAnzeige({MethodChannel? kanal})
    : _kanal = kanal ?? const MethodChannel(liveKanalName) {
    _kanal.setMethodCallHandler(_vonSwift);
  }

  final MethodChannel _kanal;
  final _linkDa = StreamController<void>.broadcast();

  @override
  Stream<void> get linkDa => _linkDa.stream;

  /// Die eine Methode, die Swift von sich aus ruft. Alles andere ist auf
  /// dieser Seite unbekannt.
  Future<Object?> _vonSwift(MethodCall aufruf) async {
    switch (aufruf.method) {
      case 'linkDa':
        _linkDa.add(null);
        return null;
      default:
        throw MissingPluginException(
          'Unbekannte Methode auf $liveKanalName: ${aufruf.method}',
        );
    }
  }

  @override
  Future<LiveErgebnis> zeige(EssenKarte karte, {required bool frisch}) async {
    try {
      final antwort = await _kanal.invokeMethod<Object?>(
        'zeige',
        essenKarteAlsMap(karte, frisch: frisch),
      );
      return switch (antwort) {
        'gestartet' => const LiveGestartet(),
        'aktualisiert' => const LiveAktualisiert(),
        'abgeschaltet' => const LiveAbgeschaltet(),
        _ => LiveFehlgeschlagen('Unbekannte Antwort auf zeige: $antwort'),
      };
    } on MissingPluginException {
      return const LiveNichtVerfuegbar();
    } on PlatformException catch (fehler) {
      return LiveFehlgeschlagen(fehler.message);
    } on Object catch (fehler) {
      // Auch was der Codec nicht kodieren kann, hält Buchen und Öffnen
      // nicht auf (Spec: „`zeige` wirft nicht").
      return LiveFehlgeschlagen('$fehler');
    }
  }

  @override
  Future<void> beendeAlle() async {
    try {
      await _kanal.invokeMethod<void>('beendeAlle');
    } on MissingPluginException {
      // Ohne Gegenseite läuft auch keine Aktivität, die zu beenden wäre.
    }
  }

  @override
  Future<LiveZiel?> nimmLink() async {
    final String? host;
    try {
      host = await _kanal.invokeMethod<String>('nimmLink');
    } on MissingPluginException {
      return null;
    }
    return switch (host) {
      'mahlzeit-eintragen' => LiveZiel.mahlzeitEintragen,
      _ => null,
    };
  }
}

/// Merkt sich jeden Aufruf, hält einen einstellbaren Link und gibt ein
/// einstellbares Ergebnis zurück — für Tests und den Simulatorlauf ohne
/// Extension. Namen und Verhalten wie `_Anzeige` in
/// `test/live/live_provider_test.dart`.
class AttrappeLiveAnzeige implements LiveAnzeige {
  /// Die `zeige`-Aufrufe, in ihrer Reihenfolge.
  final List<({EssenKarte karte, bool frisch})> zeigeAufrufe = [];

  int beendeAlleAufrufe = 0;
  int nimmLinkAufrufe = 0;

  /// Der Link, den das nächste [nimmLink] abgibt — danach ist er leer.
  LiveZiel? link;

  /// Was [zeige] zurückgibt.
  LiveErgebnis ergebnis = const LiveGestartet();

  final _linkDa = StreamController<void>.broadcast();

  @override
  Stream<void> get linkDa => _linkDa.stream;

  /// Feuert ein Ereignis auf [linkDa], wie es die Swift-Seite täte.
  void meldeLink() => _linkDa.add(null);

  @override
  Future<LiveErgebnis> zeige(EssenKarte karte, {required bool frisch}) async {
    zeigeAufrufe.add((karte: karte, frisch: frisch));
    return ergebnis;
  }

  @override
  Future<void> beendeAlle() async => beendeAlleAufrufe++;

  @override
  Future<LiveZiel?> nimmLink() async {
    nimmLinkAufrufe++;
    final ziel = link;
    link = null;
    return ziel;
  }
}

/// Die Live-Anzeige. Wirft ohne Override, wie `healthProvider` — nur
/// `main.dart` liefert die echte [KanalLiveAnzeige], jeder Test eine
/// Attrappe.
final liveAnzeigeProvider = Provider<LiveAnzeige>(
  (ref) => throw UnimplementedError(
    'liveAnzeigeProvider muss in main.dart mit KanalLiveAnzeige() '
    'überschrieben werden.',
  ),
);
