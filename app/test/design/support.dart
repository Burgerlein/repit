import 'package:flutter/cupertino.dart';

/// Gemeinsame Testhuelle für die Baukasten-Tests: Ein `CupertinoApp` liefert
/// Directionality, MediaQuery und einen Navigator — alles, was Bausteine wie
/// `IconRow` oder `Glas` beim Bauen voraussetzen dürfen, ohne dass jeder Test
/// das einzeln aufbaut. Name und Form folgen dem Aufruf aus dem Task-Brief
/// (`t.pumpWidget(huelle(StandZeile(...)))`).
Widget huelle(Widget child) {
  return CupertinoApp(
    home: CupertinoPageScaffold(child: Center(child: child)),
  );
}

/// Liest den sichtbaren Text eines `Text`-Widgets, unabhängig davon, ob er
/// als einfacher String (`data`) oder als `TextSpan` (`textSpan`) aufgebaut
/// ist. Vermeidet, dass Tests an einer Implementierungsentscheidung
/// zerbrechen, die mit dem geprüften Verhalten nichts zu tun hat.
String textOf(Text widget) {
  return widget.data ?? widget.textSpan?.toPlainText() ?? '';
}
