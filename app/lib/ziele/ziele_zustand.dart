// Was der Abschnitt „Ereignisse“ des Ziele-Schirms zeigt (#448 unter
// #404) — **gehalten, nicht je Bild gerechnet** (Hausregel 2): Titel,
// Untertitel und Vorlesetext jeder Zeile entstehen hier einmal, wenn sich
// Ereignisse oder Esstag ändern.
//
// Hier, nicht im Widget, wird `AsyncValue` gelesen: Die Widget-Schicht
// bekommt einen sealed-Typ und muss jeden Fall behandeln (Hausregel 1).
// `Messwert<T>` gilt nicht — Ereignisse sind Tims eigene Daten, leer heißt
// leer.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/ereignisse.dart';
import '../live/live_provider.dart';
import 'auszeit_texte.dart';

/// Der Abschnitt „Ereignisse“.
sealed class ZieleEreignisse {
  const ZieleEreignisse();
}

/// Die Tabelle wird gelesen. **Kein Leerzustand** — „Keine Auszeit
/// eingetragen“ während des Lesens wäre Fehler `01`.
final class EreignisseLaden extends ZieleEreignisse {
  const EreignisseLaden();

  @override
  bool operator ==(Object other) => other is EreignisseLaden;

  @override
  int get hashCode => (EreignisseLaden).hashCode;
}

/// Die Tabelle ließ sich nicht lesen. Auch das ist kein Leerzustand: Ob
/// etwas eingetragen ist, weiß die App dann nicht.
final class EreignisseUnlesbar extends ZieleEreignisse {
  const EreignisseUnlesbar();

  @override
  bool operator ==(Object other) => other is EreignisseUnlesbar;

  @override
  int get hashCode => (EreignisseUnlesbar).hashCode;
}

/// Gelesen. [zeilen] ist leer, wenn nichts eingetragen ist.
final class EreignisseGelesen extends ZieleEreignisse {
  const EreignisseGelesen({required this.zeilen, required this.freigabe});

  /// Sortiert wie das Repository (V8: `von` absteigend, dann `id`).
  final List<AuszeitZeile> zeilen;

  /// Ob der Hinweis auf die ärztliche Freigabe unter der Liste steht —
  /// sobald eine OP, Krankheit oder Verletzung eingetragen ist, egal ob
  /// laufend (V11).
  final bool freigabe;

  @override
  bool operator ==(Object other) =>
      other is EreignisseGelesen &&
      other.freigabe == freigabe &&
      listEquals(other.zeilen, zeilen);

  @override
  int get hashCode => Object.hash(freigabe, Object.hashAll(zeilen));
}

/// Eine Zeile der Liste.
@immutable
class AuszeitZeile {
  const AuszeitZeile({
    required this.ereignis,
    required this.titel,
    required this.untertitel,
    required this.vorlesen,
  });

  /// Das Ereignis, mit dem das Ändern-Blatt aufgeht.
  final Ereignis ereignis;
  final String titel;
  final String untertitel;
  final String vorlesen;

  @override
  bool operator ==(Object other) =>
      other is AuszeitZeile &&
      other.ereignis == ereignis &&
      other.titel == titel &&
      other.untertitel == untertitel &&
      other.vorlesen == vorlesen;

  @override
  int get hashCode => Object.hash(ereignis, titel, untertitel, vorlesen);
}

/// Der Abschnitt „Ereignisse“, bezogen auf den Esstag (V10).
final zieleEreignisseProvider = Provider<ZieleEreignisse>((ref) {
  final zustand = ref.watch(ereignisseProvider);
  if (zustand.hasValue) {
    final heute = ref.watch(esstagProvider);
    final ereignisse = zustand.value!;
    return EreignisseGelesen(
      zeilen: List.unmodifiable([
        for (final e in ereignisse)
          AuszeitZeile(
            ereignis: e,
            titel: auszeitTitel(e.art),
            untertitel: auszeitUntertitel(
              art: e.art,
              von: e.von,
              bis: e.bis,
              heute: heute,
            ),
            vorlesen: auszeitVorlesen(
              art: e.art,
              von: e.von,
              bis: e.bis,
              heute: heute,
            ),
          ),
      ]),
      freigabe: ereignisse.any((e) => pausiertKoerperziel(e.art)),
    );
  }
  if (zustand.hasError) return const EreignisseUnlesbar();
  return const EreignisseLaden();
});
