// Die **Online-Hälfte der Suche** (#284): wann Open Food Facts gefragt
// wird, und was davon hinter den eigenen Treffern in der einen Liste
// steht. Der Client liegt in `off_client.dart`, die Oberfläche in
// `off_abschnitt.dart` und `suche_view.dart`.
//
// Geprüft in `app/test/ernaehrung/off_suche_view_test.dart` (siehe dessen
// Dateikopf) — diese Datei darf die Tests ausführen, aber nicht verändern
// (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die Implementierung").
//
// **Kein `Messwert`, aber dieselbe Regel.** Hinter der Online-Suche steht
// kein Lauf aus Apple Health, doch die Unterscheidung ist dieselbe:
// „Open Food Facts hat nachgesehen und nichts" ([OffAnzeigeLeer]) ist
// etwas anderes als „niemand hat nachgesehen" ([OffAnzeigeKeinNetz]).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/lebensmittel_repository.dart';
import 'erfassen_provider.dart';
import 'off_client.dart';

/// Wie weit die Online-Suche zum aktuellen Suchtext ist.
sealed class OnlineSuche {
  const OnlineSuche();
}

/// Weniger als zwei Zeichen — **es wird nicht gefragt, und es gibt keine
/// Online-Anzeige.**
final class OnlineAus extends OnlineSuche {
  const OnlineAus();
}

/// Gefragt wird gleich (Entprellung) oder gerade (Anfrage unterwegs).
/// Für den Schirm ist das **ein** Zustand: Die Online-Anzeige gibt es ab
/// dem zweiten Zeichen, sonst spränge der Schirm nach einer halben
/// Sekunde.
final class OnlineLaeuft extends OnlineSuche {
  const OnlineLaeuft();
}

/// Open Food Facts hat geantwortet — oder es steht fest, dass es nicht
/// antworten wird.
final class OnlineFertig extends OnlineSuche {
  const OnlineFertig(this.ergebnis);

  final OffErgebnis ergebnis;

  @override
  bool operator ==(Object other) =>
      other is OnlineFertig && other.ergebnis == ergebnis;

  @override
  int get hashCode => ergebnis.hashCode;
}

/// Die Online-Suche zum aktuellen Suchtext.
///
/// **`autoDispose`, und jeder Zeitgeber wird in `onDispose` abgeräumt.**
/// Schließt Tim die Suche, darf keine Entprellung nachlaufen und keine
/// späte Antwort einen Zustand setzen, den niemand mehr liest — und ein
/// Widget-Test, der zwei Zeichen tippt, bräche sonst mit „Timer still
/// pending" ab.
final onlineSucheProvider =
    NotifierProvider.autoDispose<OnlineSucheNotifier, OnlineSuche>(
      OnlineSucheNotifier.new,
    );

class OnlineSucheNotifier extends Notifier<OnlineSuche> {
  @override
  OnlineSuche build() {
    final text = ref.watch(suchtextProvider).trim();
    // Gezählt wird nach dem Abschneiden der Ränder — „ H " ist ein
    // Zeichen. Ein einzelner Buchstabe trifft bei Open Food Facts
    // zehntausende Produkte, und keins davon ist gemeint.
    if (text.length < _mindestens) return const OnlineAus();

    final client = ref.watch(offClientProvider);

    // **Je Lauf eine eigene Marke**, nicht ein Zähler am Notifier. Jeder
    // neue Buchstabe baut neu, und der Neubau ruft zuerst `onDispose` des
    // vorigen Laufs: Dessen Zeitgeber steht, und eine Antwort, die noch
    // unterwegs ist, kommt an und findet ihren Lauf abgelöst. So
    // überschreibt die Antwort auf „Hafer" nie die auf „Haferdrink", auch
    // wenn sie später ankommt.
    var abgeloest = false;
    final entprellung = Timer(_entprellung, () async {
      final ergebnis = await client.suche(text);
      if (abgeloest) return;
      state = OnlineFertig(ergebnis);
    });
    ref.onDispose(() {
      abgeloest = true;
      entprellung.cancel();
    });

    return const OnlineLaeuft();
  }
}

/// Was die Suchliste aus Open Food Facts zeigt — **fünf Fälle**, und genau
/// einer davon ([OffAnzeigeAus]) heißt „es gibt keinen Online-Teil".
///
/// Seit dem 04.11.2026 gibt es **eine** Liste: Die eigenen Treffer stehen
/// vorn, der Online-Teil folgt in derselben Karte (`suche_view.dart`).
sealed class OffAnzeige {
  const OffAnzeige();
}

/// Unter zwei Zeichen: kein Online-Teil.
final class OffAnzeigeAus extends OffAnzeige {
  const OffAnzeigeAus();
}

/// Der Platzhalter — **kein Grund**, während nichts entschieden ist.
final class OffAnzeigeLaedt extends OffAnzeige {
  const OffAnzeigeLaedt();
}

/// Die Online-Zeilen, so wie sie dastehen — verworfen, zusammengefasst,
/// umsortiert, begrenzt. **Nie leer.**
final class OffAnzeigeZeilen extends OffAnzeige {
  const OffAnzeigeZeilen(this.produkte);

  final List<OffProdukt> produkte;

  @override
  bool operator ==(Object other) =>
      other is OffAnzeigeZeilen && listEquals(other.produkte, produkte);

  @override
  int get hashCode => Object.hashAll(produkte);
}

/// Open Food Facts hat nachgesehen und hat nichts, was nicht schon als
/// eigenes dasteht.
final class OffAnzeigeLeer extends OffAnzeige {
  const OffAnzeigeLeer({required this.allesSchonEigen});

  /// `true`, wenn Open Food Facts zwar Buchbares fand, aber jeder Treffer
  /// schon von einem eigenen Lebensmittel vertreten wird. Das ist eine
  /// andere Auskunft als „kennt nichts dazu".
  final bool allesSchonEigen;

  @override
  bool operator ==(Object other) =>
      other is OffAnzeigeLeer && other.allesSchonEigen == allesSchonEigen;

  @override
  int get hashCode => allesSchonEigen.hashCode;
}

/// Niemand hat nachgesehen — „Online nicht erreichbar". Die eigenen
/// Treffer stehen weiter da.
final class OffAnzeigeKeinNetz extends OffAnzeige {
  const OffAnzeigeKeinNetz();
}

/// Der Online-Teil der Suchliste — **gehalten, nicht je Bild gerechnet**
/// (`CLAUDE.md`, Hausregel 2). Zusammengefasst wird hier, einmal je
/// Antwort und je Änderung der eigenen Treffer; das Widget liest nur.
///
/// Zwei Regeln, in dieser Reihenfolge:
///
/// 1. **Ein Strichcode, der schon in den eigenen Treffern steht, erscheint
///    einmal, als eigener.** Derselbe Strichcode zweimal sähe aus wie zwei
///    Produkte, und gebucht wird ohnehin auf die eigene Kopie.
/// 2. **Verwerfen → zusammenfassen → umsortieren → begrenzen**
///    (`LebensmittelDubletten.zeilen`, #284, #327). Zusammengefasst wird
///    nach gleichem **Vergleichsnamen** (der Name ohne Größen-,
///    Packungswörter und Mengenangaben) mit Kalorien innerhalb von 3 % —
///    so vertritt auch ein eigenes Lebensmittel einen Online-Treffer — und
///    zwischen Online-Treffern zusätzlich nach **gleicher Marke mit
///    gleichen Nährwerten** (Kalorien, Eiweiß, Kohlenhydrate und Fett nah
///    am Vertreter), gleich, wie sie heißen.
///
/// Abgeglichen wird in beiden Fällen mit den eigenen Treffern, die
/// **dastehen** — nicht mit der ganzen Tabelle: Ein Produkt, dessen eigene
/// Kopie zum Suchtext nicht passt, wäre sonst nirgends zu finden.
final offAnzeigeProvider = Provider.autoDispose<OffAnzeige>((ref) {
  final online = ref.watch(onlineSucheProvider);
  final eigene =
      ref.watch(suchtrefferProvider).value ?? const <LebensmittelVorlage>[];
  final suchtext = ref.watch(suchtextProvider).trim();

  return switch (online) {
    OnlineAus() => const OffAnzeigeAus(),
    OnlineLaeuft() => const OffAnzeigeLaedt(),
    OnlineFertig(ergebnis: KeinNetz()) => const OffAnzeigeKeinNetz(),
    OnlineFertig(ergebnis: NichtGefunden()) => const OffAnzeigeLeer(
      allesSchonEigen: false,
    ),
    OnlineFertig(ergebnis: Treffer(:final produkte)) => _zeilen(
      suchtext,
      produkte,
      eigene,
    ),
  };
});

OffAnzeige _zeilen(
  String suchtext,
  List<OffProdukt> produkte,
  List<LebensmittelVorlage> eigene,
) {
  final schonDa = {for (final vorlage in eigene) ?vorlage.barcode};
  final uebrig = [
    for (final produkt in produkte)
      if (!schonDa.contains(produkt.barcode)) produkt,
  ];

  List<int> vertreter(List<LebensmittelVorlage> eigene) =>
      LebensmittelDubletten.zeilen(
        suchtext: suchtext,
        eigene: [
          for (final vorlage in eigene)
            (name: vorlage.name, kcal: vorlage.je100g.kcal),
        ],
        online: [
          for (final produkt in uebrig)
            (
              name: produkt.name,
              marke: produkt.marke,
              kcal: produkt.je100g.kcal,
              eiweissG: produkt.je100g.eiweissG,
              kohlenhydrateG: produkt.je100g.kohlenhydrateG,
              fettG: produkt.je100g.fettG,
            ),
        ],
      );

  final indizes = vertreter(eigene);
  if (indizes.isNotEmpty) {
    return OffAnzeigeZeilen([for (final i in indizes) uebrig[i]]);
  }

  // Nichts bleibt. „Schon eigen" heißt es nur, wenn ein eigenes etwas
  // vertreten hat — per Strichcode oder per Vergleichsname und Kalorien.
  // Fiel alles beim Verwerfen weg, kennt Open Food Facts nichts Buchbares
  // dazu.
  final vertretenVonEigenen =
      uebrig.length < produkte.length || vertreter(const []).isNotEmpty;
  return OffAnzeigeLeer(allesSchonEigen: vertretenVonEigenen);
}

/// Ab zwei Zeichen wird online gesucht.
const _mindestens = 2;

/// **500 ms Entprellung.** Open Food Facts begrenzt Suchanfragen; eine
/// Anfrage je Buchstabe brauchte das Kontingent bei einem Wort auf. Auf
/// dem Telefon liegen zwischen zwei Buchstaben etwa 150–300 ms — eine
/// halbe Sekunde Pause heißt fast immer „Wort fertig".
const _entprellung = Duration(milliseconds: 500);
