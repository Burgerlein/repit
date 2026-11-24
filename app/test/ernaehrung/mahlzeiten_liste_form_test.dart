// Die Mahlzeitenliste (#434) **springt nicht**, wenn das Laden endet.
//
// Heute steht die Zeile „Ziel je Mahlzeit festlegen" erst, wenn die
// Aufteilungen gelesen sind und keine gilt (Spec
// `docs/superpowers/specs/2026-11-10-mahlzeiten-aufteilung-design.md`, V9).
// Beim Laden fehlt sie ganz. Sobald das Laden endet, rutscht alles darunter,
// auf dem Ernährungs-Tab der Abschnitt Wasser, um eine Zeilenhöhe nach
// unten.
//
// ## Festlegung des Koordinators, nicht Tims Entscheidung
//
// Der Koordinator von #434 hat am 10.11.2026 festgelegt, dass dafür die
// Hausregel „Eine Anzeige, die es gibt, hat genau eine Form" (`CLAUDE.md`)
// gilt: **Während des Ladens steht an der Stelle der Zeile ein Platzhalter
// gleicher Höhe.** Tim hat das nicht gesehen und nicht freigegeben. Die
// Spec sagt in der Tabelle „Leerzustände" für diese Zeile beim Laden
// „nie" — gemeint ist die Zeile mit ihrem Text, nicht ihr Platz. Dieser
// Fall macht daraus: kein Text, aber der Platz.
//
// Geprüft wird nur der Übergang **Laden → ohne Aufteilung**. Endet das
// Laden mit einer Aufteilung, gibt es die Zeile nicht, und der Platzhalter
// fällt weg. Das bleibt ein Sprung, nach oben statt nach unten. Ob dort
// stattdessen dauerhaft Platz frei bleibt, ist eine Entwurfsfrage und
// nicht Gegenstand dieser Datei.
//
// Der Fall war beim Anlegen **rot**: Die Implementierung von #434 setzt
// beim Laden keinen Platzhalter.
//
// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
// Diese Datei darf ausgeführt, aber nicht verändert werden. Wer den Fall
// für falsch hält, meldet ihn.
//
// ## Wie geprüft wird
//
// An der Liste allein (`MahlzeitenListe`), mit einem Kasten direkt
// darunter. So steht auf dem Ernährungs-Tab der Abschnitt Wasser. Was
// gemessen wird, ist die Oberkante dieses Kastens, nicht die Höhe des
// Platzhalters selbst. Wie der Platzhalter aussieht und welchen Schlüssel
// er trägt, legt diese Datei nicht fest.
//
// **Alle Zahlen und Daten sind erfunden**, Zeitpunkte im Jahr 2099.
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart' hide MahlzeitRing;

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/data/kalorienziele.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/ernaehrung/mahlzeiten_liste.dart';
import 'package:repit/health/health_types.dart';

import '../design/support.dart' show textOf;

void main() {
  // Dienstag, 14.07.2099, 12:00 Berliner Zeit (MESZ, +2).
  final jetzt = DateTime.utc(2099, 7, 14, 10);
  const heute = '2099-07-14';

  const ziel1800 = KalorienzielFestlegung(
    abTag: '2099-01-01',
    kcal: 1800,
    herkunft: KalorienzielHerkunft.hand,
  );

  Eintrag eintrag(Mahlzeit m, double kcal) => Eintrag(
    tagesSchluessel: heute,
    mahlzeit: m,
    zeitpunkt: jetzt,
    name: 'Prüfgericht',
    naehrwerte: Naehrwerte(kcal: kcal, eiweissG: 10),
  );

  final tagesEintraege = [
    eintrag(Mahlzeit.fruehstueck, 426),
    eintrag(Mahlzeit.mittag, 672),
  ];

  /// Ohne Aufteilung, aus der echten Rechnung (`ernaehrungsTagAus`).
  ErnaehrungsTag tagOhneAufteilung({
    List<Eintrag> eigene = const [],
    bool eintraegeLaden = false,
    bool aufteilungenLaden = false,
  }) => ernaehrungsTagAus(
    tagesSchluessel: heute,
    heute: heute,
    eigene: eigene,
    fremde: LeerNachLauf<List<FremdeMahlzeit>>(gelaufen: jetzt),
    tageswerte: LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
    stammdaten: const Stammdaten(),
    jetzt: jetzt,
    kalorienziele: const [ziel1800],
    aufteilungen: const [],
    aufteilungenLaden: aufteilungenLaden,
    eintraegeLaden: eintraegeLaden,
  );

  final festlegen = find.byKey(const Key('ernaehrung-aufteilung-festlegen'));
  const danachKey = Key('test-danach');
  final danach = find.byKey(danachKey);

  /// Die Liste, darunter ein Kasten an der Stelle von Wasser.
  Future<void> zeige(WidgetTester tester, ErnaehrungsTag tag) async {
    tester.view.physicalSize = const Size(900, 4800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MahlzeitenListe(
                  tag: tag,
                  onMahlzeit: (_) {},
                  onPlus: (_) {},
                  onAufteilung: () {},
                ),
                const SizedBox(key: danachKey, height: 40),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String alleTexte(WidgetTester tester) =>
      tester.widgetList<Text>(find.byType(Text)).map(textOf).join(' ');

  group('Festlegen-Zeile: eine Form beim Laden und danach (Festlegung des '
      'Koordinators nach der Hausregel, nicht Tims Entscheidung)', () {
    for (final (name, laden) in [
      ('Einträge laden', () => tagOhneAufteilung(eintraegeLaden: true)),
      ('Aufteilungen laden', () => tagOhneAufteilung(aufteilungenLaden: true)),
    ]) {
      testWidgets('$name: was unter der Liste steht, steht an derselben '
          'Stelle wie nach dem Laden ohne Aufteilung', (tester) async {
        final geladen = tagOhneAufteilung(eigene: tagesEintraege);
        expect(
          geladen.mahlzeitenLaedt,
          isFalse,
          reason: 'Vorbedingung: Nach dem Laden lädt nichts mehr.',
        );
        await zeige(tester, geladen);
        expect(
          festlegen,
          findsOneWidget,
          reason: 'Vorbedingung: Ohne Aufteilung steht die Zeile (V9).',
        );
        final obenGeladen = tester.getTopLeft(danach).dy;

        final t = laden();
        expect(t.mahlzeitenLaedt, isTrue, reason: 'Vorbedingung');
        await zeige(tester, t);

        // `01`: Beim Laden steht kein Grund, nur der Platz.
        expect(festlegen, findsNothing);
        expect(alleTexte(tester), isNot(contains('Ziel je Mahlzeit')));
        expect(alleTexte(tester), isNot(contains('noch nichts eingetragen')));

        expect(
          tester.getTopLeft(danach).dy,
          obenGeladen,
          reason:
              'Beim Laden steht an der Stelle von „Ziel je Mahlzeit '
              'festlegen" ein Platzhalter gleicher Höhe. Sonst rutscht '
              'Wasser nach unten, sobald das Laden endet.',
        );
      });
    }
  });
}
