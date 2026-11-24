import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/inset_card.dart';

import 'support.dart';

/// Minimaler Test für `InsetCard` (Task 9, `lib/design/inset_card.dart`).
///
/// **Bewusste Lücke, siehe Bericht:** Anders als bei `IconRow` legt der Brief
/// für `InsetCard` keine Konstruktor-Signatur fest — nur den Namen.
/// `Sources/DesignSystem/InsetList.swift` zeigt `InsetCard` als reinen,
/// dummen Container; die Trennlinien zwischen Zeilen setzt dort der
/// Aufrufer selbst über ein eigenes `RowSeparator`, nicht `InsetCard`. Da
/// Task 9 keine eigene `row_separator.dart`-Datei vorsieht, bleibt offen, ob
/// diese Verantwortung nach `InsetCard` wandert oder entfällt. Dieser Test
/// nimmt die risikoärmste, direkteste Übersetzung der Swift-Vorlage an —
/// einen einzelnen `child`-Parameter — und prüft nur, dass `InsetCard`
/// seinen Inhalt zeigt. Trennlinien-Verhalten ist deshalb hier nicht
/// getestet; wer das Verhalten anders anlegt (z. B. `children: [...]` mit
/// eingebauten Trennern), muss das melden statt den Test anzupassen.
void main() {
  testWidgets('zeigt seinen Inhalt', (tester) async {
    await tester.pumpWidget(huelle(const InsetCard(child: Text('Inhalt'))));

    expect(find.text('Inhalt'), findsOneWidget);
  });
}
