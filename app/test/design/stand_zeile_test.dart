import 'package:flutter_test/flutter_test.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/design/stand_zeile.dart';

import 'support.dart';

/// Tests für `StandZeile` (Task 9, `lib/design/stand_zeile.dart`).
///
/// `StandZeile` nimmt laut Interface-Zeile des Briefs ein `Bekannt<dynamic>`
/// entgegen — es gibt **keinen** Konstruktor, der ohne Stand auskommt. Das
/// ist eine Entscheidung auf Typ-Ebene, keine, die ein Laufzeit-Test
/// nachweisen könnte: Ein Aufruf mit `NochNie`, `LeerNachLauf` oder
/// `Fehlgeschlagen` kompiliert schlicht nicht. Deshalb gibt es hier keinen
/// Test "lehnt die anderen drei Zustände ab" — er würde entweder nicht
/// kompilieren (Datei unbrauchbar) oder nichts beweisen.
///
/// **Zur offenen Frage aus dem Auftrag, was mit den anderen drei Zuständen
/// geschieht:** Dieser Baustein zeigt für sie nichts, und das ist nach
/// Rücksprache mit `docs/superpowers/specs/2026-10-23-flutter-rebuild-
/// design.md:1056` auch so beabsichtigt — dort steht `StandZeile`
/// ausdrücklich noch als offener Punkt fürs Entwurfsboard, nicht als
/// fertiger Baustein für alle vier Zustände. Die Begründung in der Sache:
/// `NochNie` hat überhaupt keinen Zeitstempel, den man als "Stand" lesen
/// könnte; `LeerNachLauf` und `Fehlgeschlagen` tragen zwar ein `gelaufen`,
/// aber das ist der Zeitpunkt eines ergebnislosen bzw. gescheiterten Laufs,
/// kein Datenstand — ihn als "Stand 14:32" zu zeigen, behauptete einen Wert,
/// den es nicht gibt. Die Entscheidung, was für diese drei Fälle stattdessen
/// erscheint (ein Platzhalter, ein Fehlertext, gar nichts), ist Sache des
/// jeweiligen Aufrufers, der über `Messwert<T>` schaltet — nicht Sache von
/// `StandZeile`. Das ist eine inhaltliche Einschätzung des Testautors, nicht
/// mit Tim abgestimmt.
/// **Nachtrag 03.11.2026 (#200/#262):** `StandZeile` nimmt seither ein
/// verpflichtendes `jetzt` entgegen und nennt das Datum, sobald der
/// Stand nicht vom selben Kalendertag ist. Die Fälle hier prüfen
/// unverändert den Fall „Stand von heute" — sie übergeben deshalb `t0`
/// auch als `jetzt`. Nichts an ihrer Aussage hat sich geändert; ohne den
/// Parameter kompilierten sie nur nicht mehr. Die neuen Fälle stehen in
/// `stand_zeile_datum_test.dart`.
void main() {
  final t0 = DateTime.utc(2026, 10, 6, 14, 32);

  // Die beiden Fälle aus dem Task-Brief, wörtlich.
  testWidgets('zeigt nur den Stand, wenn nichts laeuft', (tester) async {
    await tester.pumpWidget(
      huelle(StandZeile(Bekannt<int>(1, stand: t0, laeuft: false), jetzt: t0)),
    );

    expect(find.textContaining('Stand'), findsOneWidget);
    expect(find.textContaining('wird aktualisiert'), findsNothing);
  });

  testWidgets('nennt die laufende Aktualisierung', (tester) async {
    await tester.pumpWidget(
      huelle(StandZeile(Bekannt<int>(1, stand: t0, laeuft: true), jetzt: t0)),
    );

    expect(find.textContaining('wird aktualisiert'), findsOneWidget);
  });

  // Zusätzlich: der genaue Wortlaut aus der Design-Spec
  // (2026-10-23-flutter-rebuild-design.md:667): "Stand 14:32 · wird
  // aktualisiert" — ohne die Abstandsangabe ("vor X Minuten"), die
  // `Format.zuletztAktualisiert` sonst anhängt. `StandZeile` zeigt also
  // ausdrücklich nur Uhrzeit und Lauf-Hinweis, nicht die volle
  // "zuletzt aktualisiert"-Formatierung.
  testWidgets('zeigt "Stand " gefolgt von der Uhrzeit im Format HH:mm', (
    tester,
  ) async {
    await tester.pumpWidget(
      huelle(StandZeile(Bekannt<int>(1, stand: t0, laeuft: false), jetzt: t0)),
    );

    expect(find.text('Stand 14:32'), findsOneWidget);
  });

  testWidgets(
    'haengt den Lauf-Hinweis hinter die Uhrzeit, durch " · " getrennt',
    (tester) async {
      await tester.pumpWidget(
        huelle(StandZeile(Bekannt<int>(1, stand: t0, laeuft: true), jetzt: t0)),
      );

      expect(find.text('Stand 14:32 · wird aktualisiert'), findsOneWidget);
    },
  );
}
