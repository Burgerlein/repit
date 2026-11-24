import 'package:flutter/cupertino.dart';

import 'palette.dart';

/// Überschrift über einer Gruppe — Dart-Entsprechung von `SectionHeader` in
/// `Sources/DesignSystem/InsetList.swift`, reduziert auf die Signatur aus
/// dem Task-Brief (`SectionHeader(String)`): ohne den optionalen
/// Link/Aktion-Teil der Swift-Vorlage (`linkTitle`, `action`), den der
/// Brief für diesen Baustein nicht vorsieht.
///
/// **Erweiterung (Baukasten „Heute, kombiniert", Task H1):** `zusatz`, nach
/// `sectionHead(title, link)` in `docs/screens/components.js` — mal eine
/// Zahl („3" bei „Heute noch offen"), mal ein Verweis („Alle ›" bei
/// „Zahlen"). Für `SectionHeader` ist das dieselbe Sache: ein optionaler
/// Text rechts neben dem Titel, ohne eigenes Antippverhalten — der Entwurf
/// zeichnet ihn als reinen Text, nicht als Auslöser.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.zusatz,
    this.aufZusatz,
    this.zusatzSchluessel,
  });

  final String title;
  final String? zusatz;

  /// Macht [zusatz] zur Tür (#270, „Eintragen ›" über „Letzte Messungen").
  ///
  /// **Der Winkel folgt der Tür**, wie bei jeder Zeile im Entwurf
  /// (`sectionHead` in `docs/screens/components.js`): Er erscheint genau
  /// dann, wenn ein Ziel da ist. Ohne [aufZusatz] bleibt der Zusatz reiner
  /// Text — die Zahl „3" über „Heute noch offen" führt nirgendwohin.
  final VoidCallback? aufZusatz;

  final Key? zusatzSchluessel;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    final zusatz = this.zusatz;

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 22, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: muted,
              ),
            ),
          ),
          if (zusatz != null && aufZusatz == null)
            Text(zusatz, style: TextStyle(fontSize: 13, color: river)),
          if (zusatz != null && aufZusatz != null)
            CupertinoButton(
              key: zusatzSchluessel,
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 28),
              onPressed: aufZusatz,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(zusatz, style: TextStyle(fontSize: 13, color: river)),
                  const SizedBox(width: 3),
                  Icon(CupertinoIcons.chevron_right, size: 12, color: river),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
