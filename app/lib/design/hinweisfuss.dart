import 'package:flutter/cupertino.dart';

import 'palette.dart';

/// Hinweistext am Fuß eines Schirms — Dart-Entsprechung von `disclaimer`
/// in `docs/screens/components.js` (`'<div class="disc">' + esc(text) +
/// '</div>'`). Zeigt genau den übergebenen Satz, nichts sonst.
class Hinweisfuss extends StatelessWidget {
  const Hinweisfuss(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: muted, height: 1.4),
      ),
    );
  }
}
