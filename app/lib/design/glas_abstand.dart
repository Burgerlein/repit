import 'package:flutter/cupertino.dart';

/// Der Randabstand, den die durchscheinende Navigations- und Tableiste
/// hinterlassen (`_GlasNavigationBar`/`CupertinoTabBar` in
/// `shell/root_view.dart`).
///
/// Beide sind transluzent (`CupertinoNavigationBar.shouldFullyObstruct` bzw.
/// `CupertinoTabBar.opaque(context)` liefern `false`), also rücken weder
/// `CupertinoPageScaffold` noch `CupertinoTabScaffold` den Inhalt von sich
/// aus ein — beide hinterlassen den nötigen Abstand nur als
/// `MediaQuery.padding` (`page_scaffold.dart`/`tab_scaffold.dart`: der
/// nicht-obstruct-Zweig schreibt `padding.top` bzw. `padding.bottom`, ohne
/// selbst eine `Padding` einzufügen). Ein Schirm, der `MediaQuery.padding`
/// ignoriert, läuft unter die Leiste statt mit ihr durchzuzeichnen
/// (CLAUDE.md: „durchzeichnen statt abschneiden" — der Inhalt soll
/// scrollbar unter der Leiste durchlaufen und nur mit genügend Abstand
/// anfangen und aufhören).
///
/// **Eine Stelle, die das ausrechnet**, nicht vier: Jeder Tab-Wurzelschirm
/// (`HeuteView`, `MehrView`, `PlatzhalterTab`) und der über `MehrView`
/// erreichbare `HealthKitTestView` haben denselben Rand gebraucht — ein
/// Wert, den jeder für sich ausrechnet, ist genau die Wiederholung, die
/// beim fünften Schirm vergessen wird (task-layout-fixes, Fehler 2: die
/// oberste Zeile von `HeuteView` saß halb unter der Navigationsleiste).
class GlasAbstand {
  const GlasAbstand._();

  /// Wie weit der (+) über die Tableiste hinausragt
  /// (`RootView._fabUeberstand`, Maß aus `docs/screens/components.css`) —
  /// wer unten zu Ende scrollt, soll auch unter dem Knopf zu Ende kommen,
  /// nicht nur unter der Leiste selbst.
  static const fabUeberstand = 12.0;

  /// Der Innenabstand, den ein Schirm um seinen Inhalt legen sollte, damit
  /// er weder unter der Navigationsleiste anfängt noch unter der Tableiste
  /// samt (+) endet.
  ///
  /// Scrollende Schirme übergeben das Ergebnis als `padding` ihres
  /// `SingleChildScrollView` (siehe `HeuteView`/`MehrView`), nicht als
  /// äußere `Padding` um den ganzen Baum — eine äußere `Padding` würde den
  /// Scroll-Viewport selbst verkleinern, statt den Inhalt nur innerhalb des
  /// vollen Viewports einzurücken, und der Inhalt liefe dann nicht mehr
  /// sichtbar unter der Leiste durch, sondern hielte schon vorher an.
  static EdgeInsets of(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return EdgeInsets.only(
      top: padding.top,
      bottom: padding.bottom + fabUeberstand,
    );
  }
}

/// Legt [GlasAbstand] als `Padding` um einen **nicht scrollenden** Inhalt —
/// für `PlatzhalterTab`, dessen `Center` sonst unter Umständen knapp unter
/// die Leiste geriete. Scrollende Schirme benutzen stattdessen
/// `GlasAbstand.of(context)` direkt als `padding` ihres
/// `SingleChildScrollView` (siehe Klassenkommentar [GlasAbstand]).
class GlasRand extends StatelessWidget {
  const GlasRand({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: GlasAbstand.of(context), child: child);
}
