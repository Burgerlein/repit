import 'package:flutter/cupertino.dart';

import 'inset_card.dart';
import 'palette.dart';

/// Ein Abschnitt, der zugeklappt **eine Zeile** ist: Titel links, ein
/// Hinweis rechts, ein Winkel daneben. Ein Tipp auf die Zeile klappt ihn
/// auf, der nächste wieder zu.
///
/// Entwurf: `sectionCard({ title, hint, open: false })`
/// (`docs/screens/components.js`).
///
/// **Warum es das Bauteil gibt (#253).** Die Mechanik stand bis zum
/// 03.11.2026 von Hand in `ErholungTipps` — Tims Wunsch vom 27.10.2026,
/// „unten die Tipps sollten default eingeklappt sein". Mit dem Schlaf-Schirm
/// kommen vier weitere Abschnitte dazu. Fünfmal dieselbe Mechanik von Hand
/// wäre fünfmal die Gelegenheit, sie unterschiedlich falsch zu machen.
///
/// **Aufgeklappt bleibt aufgeklappt**, auch wenn sich die Daten darunter
/// ändern: Ein offener Abschnitt ist ein Zustand der Oberfläche, kein
/// abgeleiteter Wert. Fiele er beim nächsten Durchlauf wieder zu, wäre das
/// aus Sicht des Nutzers dasselbe wie Fehler `32`. Auf dem Schlaf-Schirm
/// heißt das zusätzlich: Er überlebt das Blättern zur Nacht davor. Dafür
/// braucht jeder Abschnitt einen eigenen [Key] — ohne ihn ordnet Flutter
/// die Zustände einer Spalte nach Stelle zu, und die Stelle verschiebt
/// sich, sobald ein Abschnitt darüber wegfällt.
///
/// **[inhalt] ist eine Funktion, kein fertiges Widget.** Zugeklappt soll
/// der Inhalt nicht nur unsichtbar sein, sondern gar nicht erst entstehen —
/// sonst rechnete der Schirm vier Diagramme, von denen keines zu sehen ist
/// (Hausregel 2 in `CLAUDE.md`).
///
/// **[hinweis] ist `null`, wenn es keine Zahl gibt**, nicht `'0'` und nicht
/// `'—'`: „`0` ist keine Antwort auf ‚kein Wert'" (`CLAUDE.md`). Die Zeile
/// behält dabei ihre Höhe — sie hängt am Titel, nicht am Hinweis —, also
/// springt nichts, sobald Werte eintreffen.
class KlappAbschnitt extends StatefulWidget {
  const KlappAbschnitt({
    super.key,
    required this.titel,
    required this.inhalt,
    this.hinweis,
    this.anfangsOffen = false,
    this.kopfSchluessel,
    this.inhaltSchluessel,
    this.randAbstand = const EdgeInsets.fromLTRB(16, 8, 16, 0),
    this.aufklappen,
  });

  /// Was links in der Zeile steht, zugeklappt wie aufgeklappt.
  final String titel;

  /// Die Zahl rechts daneben — „Ø 6:45 h". `null` heißt: dort steht
  /// nichts.
  final String? hinweis;

  /// Wird erst beim Aufklappen gerufen.
  final Widget Function() inhalt;

  /// Ob der Abschnitt **beim ersten Bau** offen steht (#79: die neueste
  /// Sitzung im Verlauf).
  ///
  /// Gilt nur einmal, beim Anlegen des Zustands: Ein offener Abschnitt ist
  /// ein Zustand der Oberfläche, und was der Nutzer danach auf- oder
  /// zuklappt, überschreibt der Wert nie — auch nicht, wenn die Daten
  /// darunter sich ändern. Additiv; ohne Angabe bleibt jeder Abschnitt wie
  /// bisher anfangs zu.
  final bool anfangsOffen;

  /// Schlüssel der tippbaren Zeile. Die Tests greifen darüber zu; ohne
  /// ihn gäbe es für „hier klappt es auf" keine strukturelle Stelle im
  /// Baum.
  final Key? kopfSchluessel;

  /// Schlüssel des Inhalts — der Teil, den es **nur aufgeklappt** gibt.
  final Key? inhaltSchluessel;

  /// Der Abstand um die Karte. Vorbelegt mit dem Maß der Karten des
  /// Schlaf-Schirms; die Erholungsseite rückt ihre Karten weiter ein und
  /// gibt deshalb ihr eigenes Maß mit.
  final EdgeInsets randAbstand;

  /// Klappt den Abschnitt von außen **auf**, sobald es feuert — nie zu.
  /// Der Link „Details" der Ernährungs-Übersicht (#406) führt so in die
  /// Herleitung, ohne eine zweite Fassung davon als eigenen Schirm.
  final Listenable? aufklappen;

  @override
  State<KlappAbschnitt> createState() => _KlappAbschnittState();
}

class _KlappAbschnittState extends State<KlappAbschnitt> {
  late bool _offen = widget.anfangsOffen;

  @override
  void initState() {
    super.initState();
    widget.aufklappen?.addListener(_oeffne);
  }

  @override
  void didUpdateWidget(KlappAbschnitt alt) {
    super.didUpdateWidget(alt);
    if (alt.aufklappen != widget.aufklappen) {
      alt.aufklappen?.removeListener(_oeffne);
      widget.aufklappen?.addListener(_oeffne);
    }
  }

  @override
  void dispose() {
    widget.aufklappen?.removeListener(_oeffne);
    super.dispose();
  }

  void _oeffne() {
    if (!_offen) setState(() => _offen = true);
  }

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final line = CupertinoDynamicColor.resolve(Palette.line, context);

    return Padding(
      padding: widget.randAbstand,
      child: InsetCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              key: widget.kopfSchluessel,
              behavior: HitTestBehavior.opaque,
              // Kein Sprung in einen anderen Schirm: Der Abschnitt geht
              // hier auf und wieder zu.
              onTap: () => setState(() => _offen = !_offen),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Text(
                      widget.titel,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        widget.hinweis ?? '',
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: muted),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      _offen
                          ? CupertinoIcons.chevron_down
                          : CupertinoIcons.chevron_right,
                      size: 13,
                      color: muted.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
            if (_offen) ...[
              Container(height: 1, color: line),
              Padding(
                key: widget.inhaltSchluessel,
                padding: const EdgeInsets.fromLTRB(13, 11, 13, 5),
                child: widget.inhalt(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
