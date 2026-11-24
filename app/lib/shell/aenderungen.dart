// Das Änderungsblatt — „Was ist neu" (#89).
//
// Spec: `docs/superpowers/specs/2026-11-19-aenderungsblatt-design.md`,
// Entwurf: `docs/screens/screens/aenderungen.js` (Freigabe Tim, 19.11.2026).
// Zustände und Übergänge sind durch `test/shell/aenderungsblatt_test.dart`
// vorgegeben, die echte Datei durch `test/aenderungen_datei_test.dart` —
// beide dürfen ausgeführt, aber nicht verändert werden (`CLAUDE.md`).
//
// Die Quelle der Einträge ist das JSON-Asset `assets/aenderungen.json`,
// **einmal beim Start gelesen und gehalten** (Regel 2, wie
// `uebungsbilderProvider`): `main()` lädt es mit [ladeAenderungen] und
// überschreibt [aenderungenProvider]. Die Reihenfolge der Datei ist die
// Reihenfolge im Blatt — es wird nicht sortiert; die laufende Fassung ist
// der erste Eintrag, und die Mehr-Fußzeile ([FassungsFusszeile]) liest den
// Namen von dort, nirgendwo steht er ein zweites Mal.
//
// **Kein Leerzustand:** Die Datei liegt im Bundle und kann zur Laufzeit
// nicht fehlen; eine leere oder kaputte Datei ist ein Programmierfehler,
// den der Wächtertest vor jedem Build meldet. [ladeAenderungen] parst
// deshalb streng und fängt nichts ab.
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/formatierung.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../ernaehrung/wasser_bausteine.dart'
    show BlattKopf, blattKopfKnopf, BlattKapitel, Trennlinie;
import '../koerper/umfaenge_eintragen.dart' show UmfaengeEintragenSeite;
import '../uebernahme/uebernahme_view.dart' show UebernahmeSeite;
import '../ziele/ziele_view.dart' show ZieleSeite;
import 'router.dart';
import 'ziele.dart';

// [zielZuAppTarget] gibt den Typ zurück — wer die Tabelle benutzt, bekommt
// ihn mit, ohne `ziele.dart` eigens zu importieren.
export 'ziele.dart' show AppTarget;

/// Ein Eintrag im Änderungsblatt: Titel, genau ein Satz, optionales
/// Sprungziel. Die Texte sind für Nicht-Informatiker; Interna stehen gar
/// nicht in der Datei (Spec #89).
@immutable
class AenderungsEintrag {
  const AenderungsEintrag({
    required this.titel,
    required this.text,
    this.ziel,
  });

  final String titel;

  /// Der eine Satz, was man davon merkt.
  final String text;

  /// Benennt ein Sprungziel aus der Zuordnungstabelle ([zielZuAppTarget]),
  /// oder `null`: Dann ist der Eintrag reine Anzeige — der Winkel folgt der
  /// Tür.
  final String? ziel;
}

/// Eine Fassung der App mit ihren Einträgen. [stand] ist ein optionaler
/// ISO-Tagesstring — ein Metadatum der App, kein Nutzer-Ereignis; in
/// `app/lib/` steht trotzdem kein Datum, nur im Asset (Spec #89).
@immutable
class Fassung {
  const Fassung({required this.fassung, this.stand, required this.eintraege});

  final String fassung;
  final String? stand;
  final List<AenderungsEintrag> eintraege;
}

/// Die Fassungsliste, **einmal beim Start geladen** und danach nur noch
/// gelesen — gehalten, nicht je Zugriff gerechnet (Regel 2).
///
/// Wirft ohne Override, wie `uebungsbilderProvider`: Nur `main()` setzt den
/// Wert ([ladeAenderungen]); jeder Test überschreibt ihn selbst.
final aenderungenProvider = Provider<List<Fassung>>(
  (ref) => throw UnimplementedError(
    'aenderungenProvider muss in main.dart mit dem Ergebnis von '
    'ladeAenderungen() überschrieben werden.',
  ),
);

/// Liest `assets/aenderungen.json` aus dem Bündel — streng: Eine Datei, die
/// nicht parst, ist ein Programmierfehler, den `aenderungen_datei_test.dart`
/// vor jedem Build meldet, kein Laufzeitfall, den es abzufangen gälte.
Future<List<Fassung>> ladeAenderungen(AssetBundle bundle) async {
  final text = await bundle.loadString('assets/aenderungen.json');
  final liste = jsonDecode(text) as List<dynamic>;
  return [
    for (final fassung in liste.cast<Map<String, dynamic>>())
      Fassung(
        fassung: fassung['fassung'] as String,
        stand: fassung['stand'] as String?,
        eintraege: [
          for (final eintrag in (fassung['eintraege'] as List<dynamic>)
              .cast<Map<String, dynamic>>())
            AenderungsEintrag(
              titel: eintrag['titel'] as String,
              text: eintrag['text'] as String,
              ziel: eintrag['ziel'] as String?,
            ),
        ],
      ),
  ];
}

/// Die feste Zuordnungstabelle `ziel` → [AppTarget] — die **eine** Stelle
/// im Code (Spec #89). Ein unbekanntes Ziel liefert `null`: Das ist ein
/// Programmierfehler, kein Laufzeitfall; der Wächtertest prüft die echte
/// Datei gegen genau diese Funktion und macht daraus einen roten Build.
///
/// Tab-Fälle und Push-Ziele stehen nebeneinander (Entscheidung zu #89):
/// „ernaehrung" und „heute" wechseln den Tab, die übrigen schieben über
/// `AppTarget.aktuell(...)` auf den Stapel des aktuell gewählten Tabs —
/// dieselbe Regel wie in `MehrView`, ein Menüpunkt wechselt nie den Tab.
///
/// **Nur routerfreie Seiten stehen hier.** `ErholungSeite`, `SchlafSeite`
/// und `KoerperSeite` verlangen den `AppRouter` im Konstruktor; eine
/// Tabelle mit der Signatur `String → AppTarget?` kann ihn nicht liefern.
/// Einträge zu diesen Schirmen bleiben in der Datei ohne `ziel`, bis die
/// Seiten ihn selbst besorgen können.
AppTarget? zielZuAppTarget(String ziel) => switch (ziel) {
  'heute' => AppTarget.heute(),
  'ernaehrung' => AppTarget.ernaehrung(),
  'ziele' => AppTarget.aktuell((context) => const ZieleSeite()),
  'umfaenge-messen' =>
    AppTarget.aktuell((context) => const UmfaengeEintragenSeite()),
  'daten-uebernehmen' =>
    AppTarget.aktuell((context) => const UebernahmeSeite()),
  _ => null,
};

/// Öffnet das Änderungsblatt über der aufrufenden Seite — ein Blatt, kein
/// Schirm (`showCupertinoModalPopup`, wie `wasser_blatt.dart`). Öffnen und
/// Schließen sind keine Navigation über den `AppRouter`.
Future<void> zeigeAenderungsBlatt(
  BuildContext context, {
  required AppRouter router,
}) => showCupertinoModalPopup<void>(
  context: context,
  builder: (_) => AenderungsBlatt(router: router),
);

/// Die Fußzeile der Mehr-Seite: unten, klein, zentriert
/// `Fassung <erste fassung>`, antippbar — der Zugang zum Blatt (Spec #89,
/// `docs/screens/screens/mehr.js`). Kein eigener Menüpunkt.
///
/// Liest die Fassungsliste **behutsam** statt als `ConsumerWidget`:
/// `MehrView` wird in bestehenden, unantastbaren Tests ohne
/// `ProviderScope` gepumpt (`mehr_view_test.dart`, `huelle(...)`) oder mit
/// einem Container ohne Override (`erholung_view_test.dart`). Ohne Scope
/// oder ohne Wert zeigt die Fußzeile nichts — in der App setzt `main()`
/// den Wert immer, bevor das erste Bild steht.
class FassungsFusszeile extends StatelessWidget {
  const FassungsFusszeile({super.key, required this.router});

  final AppRouter router;

  List<Fassung>? _fassungen(BuildContext context) {
    final ProviderContainer container;
    try {
      container = ProviderScope.containerOf(context, listen: false);
    } on StateError {
      return null; // Testhülle ohne ProviderScope.
    }
    try {
      return container.read(aenderungenProvider);
    } on Object {
      return null; // Container ohne Override — nur in fremden Tests.
    }
  }

  @override
  Widget build(BuildContext context) {
    final fassungen = _fassungen(context);
    if (fassungen == null || fassungen.isEmpty) {
      return const SizedBox.shrink();
    }

    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final stil = TextStyle(fontSize: 13, color: muted);

    // Der Fassungsname steht in einem eigenen `Text`, der Winkel daneben:
    // Der Wortlaut „Fassung <erste fassung>" ist der vereinbarte
    // Tippbereich (`aenderungsblatt_test.dart`), der Winkel Dekoration.
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => zeigeAenderungsBlatt(context, router: router),
        child: Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Fassung ${fassungen.first.fassung}', style: stil),
              Text(' ›', style: stil),
            ],
          ),
        ),
      ),
    );
  }
}

/// Der Inhalt des Blatts „Was ist neu": je Fassung eine Überschrift und
/// eine Karte mit den Einträgen, in Dateireihenfolge. „Fertig" schließt;
/// ein Eintrag mit `ziel` trägt den Winkel, schließt das Blatt und öffnet
/// den Schirm über `AppRouter.open(...)` — Views setzen weder Tab noch
/// Pfad direkt (`CLAUDE.md`).
class AenderungsBlatt extends ConsumerWidget {
  const AenderungsBlatt({super.key, required this.router});

  final AppRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fassungen = ref.watch(aenderungenProvider);
    final bg = CupertinoDynamicColor.resolve(Palette.bg, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      // Feste Höhe wie `wasser_blatt.dart` — das Blatt hat genau einen
      // Zustand und eine Form, egal wie viele Fassungen es trägt.
      height: MediaQuery.of(context).size.height * 0.62,
      child: DefaultTextStyle(
        style: TextStyle(color: ink, fontSize: 15),
        child: Column(
          children: [
            BlattKopf(
              titel: 'Was ist neu',
              // „Fertig" steht links, wie im Entwurf (`sheet({ lead: … })`).
              links: blattKopfKnopf(
                key: const Key('aenderungen-fertig'),
                titel: 'Fertig',
                fett: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final fassung in fassungen) ...[
                      BlattKapitel(_ueberschrift(fassung)),
                      InsetCard(child: _karte(context, fassung)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// „Fassung v0.1 · 19.11.2026" — mit `stand` nur, falls vorhanden. Das
  /// Datum läuft über den gemeinsamen Formatierer, nie über die
  /// Standardformatierung (`CLAUDE.md`).
  String _ueberschrift(Fassung fassung) {
    final stand = fassung.stand;
    if (stand == null) return 'Fassung ${fassung.fassung}';
    final teile = stand.split('-').map(int.parse).toList();
    final datum = Format.tag(DateTime.utc(teile[0], teile[1], teile[2]));
    return 'Fassung ${fassung.fassung} · $datum';
  }

  Widget _karte(BuildContext context, Fassung fassung) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < fassung.eintraege.length; i++) ...[
          if (i > 0) const Trennlinie(),
          _zeile(context, fassung.eintraege[i]),
        ],
      ],
    );
  }

  /// Ein Eintrag: Titel fett, darunter der eine Satz. **Der Winkel folgt
  /// der Tür:** Nur mit `ziel` gibt es Tipp-Handler, Winkel und
  /// Knopf-Semantik; ohne ist die Zeile reine Anzeige.
  Widget _zeile(BuildContext context, AenderungsEintrag eintrag) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final ziel = eintrag.ziel;

    final inhalt = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eintrag.titel,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  eintrag.text,
                  style: TextStyle(fontSize: 13, color: muted),
                ),
              ],
            ),
          ),
          if (ziel != null) ...[
            const SizedBox(width: 8),
            Icon(CupertinoIcons.chevron_right, size: 16, color: muted),
          ],
        ],
      ),
    );

    if (ziel == null) return inhalt;

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _oeffne(context, ziel),
        child: inhalt,
      ),
    );
  }

  void _oeffne(BuildContext context, String ziel) {
    final target = zielZuAppTarget(ziel);
    // Ein unbekanntes Ziel ist ein Programmierfehler, den der Wächtertest
    // vor jedem Build meldet — hier bleibt nur, nichts zu tun.
    if (target == null) return;
    Navigator.of(context).pop();
    router.open(target);
  }
}
