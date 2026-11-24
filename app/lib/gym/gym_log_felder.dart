// Das Eingabefeld des Erfassen-Schirms (#78): ein Textfeld, dessen Text dem
// Provider gehört.
//
// **Die Quelle der Wahrheit ist der Entwurf im Notifier**, nicht der
// Controller (Spec 9.2, Fehler `32`). Der Controller hier ist nur der
// Griff, den Flutter für den Cursor braucht: Er wird beim Bau mit dem Wert
// aus dem Provider belegt, und was der Nutzer tippt, geht sofort in den
// Provider zurück. Ein Feld, das neu gebaut wird — beim Aufklappen einer
// Karte, beim Blättern im Vollbild —, steht deshalb mit seinem Wert wieder
// da.
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// Nur Ziffern, Komma und Punkt: Komma und Punkt werden beide gelesen
/// (`GymSessionBuilder`), ausgegeben wird lokalisiert (Spec 3.5).
final gymDezimalFormat = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

/// Nur Ziffern.
final gymZifferFormat = FilteringTextInputFormatter.digitsOnly;

/// Ein einzeiliges oder mehrzeiliges Feld ohne eigene Umrandung — die
/// Fläche zeichnet der Aufrufer.
class GymFeld extends StatefulWidget {
  const GymFeld({
    super.key,
    required this.wert,
    required this.onChanged,
    required this.stil,
    this.onAktiv,
    this.tastatur,
    this.formatierer = const [],
    this.gesperrt = false,
    this.ausrichtung = TextAlign.right,
    this.hinweis,
    this.hinweisStil,
    this.maxZeilen = 1,
  });

  /// Was im Feld steht — aus dem Provider.
  final String wert;

  final ValueChanged<String> onChanged;

  /// Das Feld wurde angetippt oder verändert — damit die Karte weiß, in
  /// welcher Übung man gerade ist.
  final VoidCallback? onAktiv;

  final TextStyle stil;
  final TextInputType? tastatur;
  final List<TextInputFormatter> formatierer;

  /// Gesperrt heißt: kein Feld, in das man tippen könnte — aber dieselbe
  /// Form (Zeitübung, Laden).
  final bool gesperrt;

  final TextAlign ausrichtung;

  /// Der Hinweis im leeren Feld (`placeholder`), wo ein Feld einen eigenen
  /// trägt. Die Satzzeilen zeichnen ihren Platzhalter selbst.
  final String? hinweis;
  final TextStyle? hinweisStil;
  final int maxZeilen;

  @override
  State<GymFeld> createState() => _GymFeldState();
}

class _GymFeldState extends State<GymFeld> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.wert,
  );

  @override
  void didUpdateWidget(GymFeld alt) {
    super.didUpdateWidget(alt);
    // Der Provider hat einen anderen Text als das Feld (etwa weil er eine
    // Eingabe nicht angenommen hat): Er gewinnt.
    if (widget.wert != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.wert,
        selection: TextSelection.collapsed(offset: widget.wert.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField(
      controller: _controller,
      readOnly: widget.gesperrt,
      enableInteractiveSelection: !widget.gesperrt,
      keyboardType: widget.tastatur,
      inputFormatters: widget.formatierer,
      textAlign: widget.ausrichtung,
      style: widget.stil,
      maxLines: widget.maxZeilen,
      minLines: 1,
      padding: EdgeInsets.zero,
      decoration: null,
      placeholder: widget.hinweis,
      placeholderStyle: widget.hinweisStil,
      onChanged: (text) {
        widget.onAktiv?.call();
        widget.onChanged(text);
      },
      onTap: widget.onAktiv,
    );
  }
}
