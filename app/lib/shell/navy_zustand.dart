// Körperfett nach Maßband (#479 unter #88) — die Verdrahtung der
// Navy-Zeile im Messung-Detail.
//
// **Die Rechnung liegt im Kern** (`NavyKoerperfett.prozent`,
// `navy_koerperfett_test.dart`) und wird hier nur gerufen. Was hier
// entsteht, ist die Antwort auf „warum steht da keine Zahl?" — und die ist
// nicht eine, sondern mehrere: Es wird noch gelesen, es ließ sich nicht
// lesen, es fehlt das Halsmaß, es fehlt die Körpergröße. Eine einzige
// Auskunft („kein Maßband-Wert") schickte Tim das Maßband suchen, obwohl
// die Körpergröße fehlt.
//
// Hier, nicht im Widget, wird `AsyncValue` gelesen: Die Widget-Schicht
// bekommt einen sealed-Typ und muss jeden Fall behandeln (Hausregel 1).
// `Messwert<T>` gilt nicht — Umfänge und Stammdaten sind Tims eigene
// Daten, es gibt keinen Lauf aus Apple Health, der leer ausgehen kann.
//
// **Die Körpergröße kommt aus den Stammdaten und sonst nirgendwoher.**
// Eine Konstante im Quelltext wäre eine Angabe über den Nutzer, die
// niemand gemacht hat — dasselbe Argument wie bei
// `Stammdaten.alterAm` („`null`, nicht `0`").
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/stammdaten.dart';
import '../koerper/umfaenge_provider.dart';

/// Die eine Stelle, an der die Navy-Rechnung des Kerns gerufen wird.
///
/// **Fehlt eine der drei Zahlen, gibt es keine** — geschätzt wird nicht.
/// Und auch mit allen dreien darf `null` herauskommen: Der Kern weist eine
/// Taille unterhalb des Halses und ein Ergebnis außerhalb von 2 bis 50
/// Prozent zurück, weil sich dort jemand vermessen hat.
double? navyProzentAus({double? tailleCm, double? halsCm, double? groesseCm}) {
  if (tailleCm == null || halsCm == null || groesseCm == null) return null;
  return NavyKoerperfett.prozent(
    tailleCm: tailleCm,
    halsCm: halsCm,
    groesseCm: groesseCm,
  );
}

/// Warum keine Zahl dasteht. `null` heißt: Sie steht da.
///
/// **Vier verschiedene Auskünfte und nicht eine**: „kein Halsmaß" ist etwas
/// anderes als „keine Körpergröße", und beide sind etwas anderes als „noch
/// gar nicht gemessen" (#479).
enum NavyGrund {
  /// Weder Taille noch Hals sind je gemessen worden.
  ohneMass,

  /// Das Halsmaß fehlt — Navy braucht Taille **und** Hals.
  ohneHals,

  /// Das Taillenmaß fehlt.
  ohneTaille,

  /// Beide gibt es, aber nie an demselben Tag. Zwei Zahlen aus zwei Monaten
  /// ergäben ein Verhältnis zweier verschiedener Körper.
  ohneGemeinsameMessung,

  /// Die Körpergröße steht nicht in den Stammdaten.
  ohneGroesse,

  /// Alle drei liegen vor, und die Rechnung gibt trotzdem nichts her — da
  /// hat sich jemand vermessen. Eine erfundene Zahl wäre schlimmer als
  /// keine.
  unplausibel,
}

/// Der Zustand der Navy-Zeile.
sealed class NavyStand {
  const NavyStand();
}

/// Umfänge oder Stammdaten werden noch gelesen. **Hier steht weder eine
/// Zahl noch ein Grund** — ob Taille und Hals vorliegen, weiß die App jetzt
/// nicht, und genau das war `01`.
final class NavyLaedt extends NavyStand {
  const NavyLaedt();

  @override
  bool operator ==(Object other) => other is NavyLaedt;

  @override
  int get hashCode => (NavyLaedt).hashCode;
}

/// Das Lesen ist gescheitert. Keine Aussage über die Datenlage — und keine
/// über einen laufenden Versuch: Es läuft nichts mehr.
final class NavyUnlesbar extends NavyStand {
  const NavyUnlesbar();

  @override
  bool operator ==(Object other) => other is NavyUnlesbar;

  @override
  int get hashCode => (NavyUnlesbar).hashCode;
}

/// Gelesen: entweder [prozent] oder [grund], nie beides und nie keines.
///
/// Werttyp mit `==` und `hashCode`, weil er von einem Provider gehalten und
/// Abhängigkeit des Detailzustands ist (`CLAUDE.md`, Fehler `03`).
@immutable
final class NavyGelesen extends NavyStand {
  const NavyGelesen({
    required this.prozent,
    required this.grund,
    required this.tailleCm,
    required this.halsCm,
    required this.groesseCm,
  });

  /// Der geschätzte Körperfettanteil in Prozent, oder `null`.
  final double? prozent;

  /// Warum [prozent] `null` ist; `null`, wenn eine Zahl dasteht.
  final NavyGrund? grund;

  /// Die drei Eingangszahlen — Taille und Hals aus **derselben** Messung,
  /// die Größe aus den Stammdaten. Sie stehen hier, damit der
  /// Detailzustand sein `navyProzent` aus denselben Zahlen füllt und nicht
  /// aus einer zweiten Quelle.
  final double? tailleCm;
  final double? halsCm;
  final double? groesseCm;

  @override
  bool operator ==(Object other) =>
      other is NavyGelesen &&
      other.prozent == prozent &&
      other.grund == grund &&
      other.tailleCm == tailleCm &&
      other.halsCm == halsCm &&
      other.groesseCm == groesseCm;

  @override
  int get hashCode => Object.hash(prozent, grund, tailleCm, halsCm, groesseCm);
}

/// Die Nutzlast, oder `null` — über einen `switch` über den sealed-Typ,
/// nicht über einen `is`-Test daneben (#489).
NavyGelesen? navyWerte(NavyStand stand) => switch (stand) {
  final NavyGelesen gelesen => gelesen,
  NavyLaedt() || NavyUnlesbar() => null,
};

/// Taille, Hals und Körpergröße zu einer Zahl — oder zu dem Grund, warum es
/// keine gibt.
///
/// [messungen] kommt **absteigend** herein, die jüngste zuerst (so liefert
/// sie `UmfaengeRepository.messungen`).
///
/// **Taille und Hals stammen aus derselben Messung** — so macht es auch die
/// Swift-Fassung (`BodyStore.navyPercent`). Ein Halsmaß von vor drei
/// Monaten mit der Taille von heute zu verrechnen ergäbe ein Verhältnis,
/// das es an keinem Tag gab.
NavyGelesen navyGelesenAus({
  required List<Umfangsmessung> messungen,
  required int? groesseCm,
}) {
  var hatTaille = false;
  var hatHals = false;
  for (final messung in messungen) {
    final taille = messung.werte[Umfang.taille];
    final hals = messung.werte[Umfang.hals];
    hatTaille |= taille != null;
    hatHals |= hals != null;
    if (taille == null || hals == null) continue;

    // Die jüngste Messung, die beide trägt — gefunden, Schluss.
    if (groesseCm == null) {
      return NavyGelesen(
        prozent: null,
        grund: NavyGrund.ohneGroesse,
        tailleCm: taille,
        halsCm: hals,
        groesseCm: null,
      );
    }
    final prozent = navyProzentAus(
      tailleCm: taille,
      halsCm: hals,
      groesseCm: groesseCm.toDouble(),
    );
    return NavyGelesen(
      prozent: prozent,
      grund: prozent == null ? NavyGrund.unplausibel : null,
      tailleCm: taille,
      halsCm: hals,
      groesseCm: groesseCm.toDouble(),
    );
  }

  return NavyGelesen(
    prozent: null,
    grund: switch ((hatTaille, hatHals)) {
      (false, false) => NavyGrund.ohneMass,
      (true, false) => NavyGrund.ohneHals,
      (false, true) => NavyGrund.ohneTaille,
      (true, true) => NavyGrund.ohneGemeinsameMessung,
    },
    tailleCm: null,
    halsCm: null,
    groesseCm: groesseCm?.toDouble(),
  );
}

/// Die Navy-Zeile, einmal gerechnet und gehalten (Hausregel 2).
///
/// **Beide Quellen zählen gleich**: Scheitert eine, ist die Zeile
/// unlesbar; läuft eine noch, lädt sie. Ein `hasValue` auf nur einer von
/// beiden ließe die Zeile „keine Körpergröße" sagen, während die
/// Stammdaten noch unterwegs sind.
final navyStandProvider = Provider<NavyStand>((ref) {
  final umfaenge = ref.watch(umfaengeMessungenProvider);
  final stammdaten = ref.watch(stammdatenProvider);

  if (umfaenge.hasError || stammdaten.hasError) return const NavyUnlesbar();
  if (!umfaenge.hasValue || !stammdaten.hasValue) return const NavyLaedt();

  return navyGelesenAus(
    messungen: umfaenge.value!,
    groesseCm: stammdaten.value!.groesseCm,
  );
});
