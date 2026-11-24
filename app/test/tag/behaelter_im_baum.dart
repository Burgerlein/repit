import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Testhilfe zum laufenden Tag (#455 unter #375). **Kein Test.**
///
/// Wirkt wie `UncontrolledProviderScope` und nimmt dieselben Argumente.
/// Zusätzlich räumt sie den [container] ab, sobald der Baum abgebaut wird.
///
/// ## Warum
///
/// `laufenderTagProvider` stellt einen Zeitgeber auf `endetSpaetestens`
/// (V9, verlangt in `laufender_tag_test.dart`). Er läuft, solange der
/// Behälter lebt. `testWidgets` prüft nach dem Testkörper, ob noch ein
/// Timer aussteht: Es baut den Baum ab und fragt dann sofort nach. Ein
/// `addTearDown(container.dispose)` läuft erst danach, und dann scheitert
/// jeder Widget-Test, dessen Schirm den laufenden Tag liest, mit „A Timer
/// is still pending even after the widget tree was disposed.“
///
/// Mit dieser Hülle lebt der Behälter so lange wie der Baum, so wie bei
/// einem `ProviderScope`. Am Verhalten des Tests ändert sich nichts: Der
/// Testkörper ist vorbei, wenn der Baum abgebaut wird. Das
/// `addTearDown(container.dispose)` der Hüllen darf stehen bleiben, denn
/// ein zweites `dispose` tut nichts.
///
/// **Ein Fall, der den Baum mitten im Test abbaut und denselben Behälter
/// danach weiterliest, darf diese Hülle nicht benutzen.** Nach dem Abbau
/// ist der Behälter weg.
///
/// Geschrieben vom Test-Agenten; nicht von Tim gesehen.
class BehaelterImBaum extends StatefulWidget {
  const BehaelterImBaum({
    super.key,
    required this.container,
    required this.child,
  });

  final ProviderContainer container;
  final Widget child;

  @override
  State<BehaelterImBaum> createState() => _BehaelterImBaumState();
}

class _BehaelterImBaumState extends State<BehaelterImBaum> {
  @override
  void didUpdateWidget(BehaelterImBaum oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Wird an derselben Stelle ein neuer Behälter eingehängt, wird der
    // alte erst nach dem Bild abgeräumt. Bis dahin hängen die Leser noch
    // an ihm.
    final alt = oldWidget.container;
    if (!identical(alt, widget.container)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => alt.dispose());
    }
  }

  @override
  void dispose() {
    // Die Kinder sind zu diesem Zeitpunkt schon abgebaut, sie lesen nichts
    // mehr aus dem Behälter (`_InactiveElements._unmount` baut die Kinder
    // vor ihrem Elternteil ab).
    widget.container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UncontrolledProviderScope(
    container: widget.container,
    child: widget.child,
  );
}
