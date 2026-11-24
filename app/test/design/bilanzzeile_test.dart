import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/bilanzzeile.dart';

import 'support.dart';

/// Tests für `Bilanzzeile` (Baukasten „Heute, kombiniert", Task H1), nach
/// `balanceLine({ wert, note })` in `docs/screens/components.js`.
///
/// **Ersetzt `bilanzkarte_test.dart`.** Die ursprüngliche `Bilanzkarte` —
/// mit aufgenommen/verbraucht/Differenz, Vorzeichen-Logik und
/// Farbumschlag bei Überschuss/Defizit — ist zwischen Erteilung und
/// Abgabe des Auftrags aus dem Entwurf verschwunden (Commit „Nimm die
/// Energiebilanz aus der kombinierten Startseite"): Sie stand als größte
/// Zahl über allem, war aber die Differenz zweier Schätzungen (Aufnahme
/// ~Mitschreiben, Verbrauch ~Formel) und 16 Stunden am Tag irreführend
/// („−800" um neun Uhr sieht nach Hungern aus, siehe Kommentarkopf in
/// `heute-kombi.js`).
///
/// Ersatz ist `balanceLine`, eine „ruhige Zeile" ohne jede eigene Logik:
/// zwei Strings, einer schon fertig mit Vorzeichen und Einheit formatiert
/// (`wert`, im Entwurf z. B. ein negativer kcal-Wert), der andere eine
/// Einordnung, die der Schirm liefert (`note: 'Schätzung · aussagekräftig
/// erst am Abend'`). Der Beispielwert unten (`+540 kcal`) ist erfunden,
/// bewusst mit anderem Vorzeichen und anderer Größenordnung als das
/// Entwurfsbeispiel — siehe Hinweis zu Tims echten Werten in
/// `ringe_test.dart`/`kacheln_test.dart`: Dieselbe Vorsicht gilt hier,
/// auch wenn `balanceLine`s Beispielzahl im Board selbst keine eindeutig
/// zuordenbare echte Messgröße ist (anders als Kalorien/Makros/Schritte
/// anderswo auf dem Board). Die
/// Entscheidung, *ob* und *wann* diese Zeile unter den Ringen steht
/// („steht noch zur Wahl", so der Entwurfskommentar), ist Zustandslogik
/// des Schirms — nicht Sache dieses Bausteins, genau wie bei allen
/// anderen hier: schlichte Werte rein, keine Zustände.
///
/// Da der Baustein keine eigene Logik hat (kein Vorzeichen, keine Farbe,
/// keine Berechnung), bleibt die Prüfung so knapp wie bei `Hinweisfuss` —
/// zeigt beide übergebenen Strings, sonst nichts zu prüfen.
void main() {
  testWidgets('zeigt den uebergebenen Wert', (tester) async {
    await tester.pumpWidget(
      huelle(
        const Bilanzzeile(
          wert: '+540 kcal',
          hinweis: 'Schätzung · aussagekräftig erst am Abend',
        ),
      ),
    );

    expect(find.text('+540 kcal'), findsOneWidget);
  });

  testWidgets('zeigt den uebergebenen Hinweis', (tester) async {
    await tester.pumpWidget(
      huelle(
        const Bilanzzeile(
          wert: '+540 kcal',
          hinweis: 'Schätzung · aussagekräftig erst am Abend',
        ),
      ),
    );

    expect(
      find.text('Schätzung · aussagekräftig erst am Abend'),
      findsOneWidget,
    );
  });
}
