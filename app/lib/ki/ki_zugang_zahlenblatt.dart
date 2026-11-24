// Die beiden Zahlenblätter des KI-Zugangs (#339): Monatslimit und Preis
// je Million Token. Der Entwurf zeichnet die Zeilen als Türen
// (`ki-zugang.js`, „Monatslimit", „Preis je Mio. Token"), die Blätter
// dahinter aber nicht — sie folgen der Form von „Gemini-Schlüssel": Leiste
// mit Abbrechen/Sichern, eine Formularkarte, ein Fuß.
//
// Beträge sind US-Dollar (Tim, 04.11.2026). Komma und Punkt gelten beide
// als Dezimaltrennzeichen — die deutsche Ziffern-Tastatur liefert das
// Komma.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/palette.dart';
import '../design/zahlen.dart';
import 'ki_zugang_bausteine.dart';
import 'ki_zugang_provider.dart';

/// Öffnet „Monatslimit".
Future<void> zeigeLimit(BuildContext context, KiTopf topf) =>
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => _ZahlenBlatt(
        key: const Key('ki-limit-blatt'),
        titel: 'Monatslimit',
        felder: [('Limit', topf.limitUsd)],
        fuss:
            'Eine Bremse dieser App, keine Sperre bei Google. Erreicht die '
            'Selbstzählung des Monats das Limit, startet bis zum Ersten des '
            'nächsten Monats keine neue Anfrage.',
        gueltig: (werte) => werte.single > 0,
        sichere: (ref, werte) =>
            ref.read(kiZugangProvider.notifier).setzeLimit(werte.single),
      ),
    );

/// Öffnet „Preis je Mio. Token" für das Modell, das die Foto-Schätzung
/// gerade nutzt.
Future<void> zeigePreis(BuildContext context, KiTopf topf) =>
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => _ZahlenBlatt(
        key: const Key('ki-preis-blatt'),
        titel: 'Preis je Mio. Token',
        felder: [
          ('Eingabe', topf.preis?.eingabeJeMio),
          ('Ausgabe', topf.preis?.ausgabeJeMio),
        ],
        fuss:
            'Für ${topf.preisModell}, in US-Dollar je Million Token. '
            'Denk-Token zählen als Ausgabe. Google gibt die Preise nicht über '
            'die Schnittstelle heraus — der aktuelle steht in der '
            'Gemini-Preisliste.',
        gueltig: (werte) => werte.every((w) => w >= 0),
        sichere: (ref, werte) => ref
            .read(kiZugangProvider.notifier)
            .setzePreis(
              KiPreis(eingabeJeMio: werte[0], ausgabeJeMio: werte[1]),
            ),
      ),
    );

class _ZahlenBlatt extends ConsumerStatefulWidget {
  const _ZahlenBlatt({
    super.key,
    required this.titel,
    required this.felder,
    required this.fuss,
    required this.gueltig,
    required this.sichere,
  });

  final String titel;

  /// Beschriftung und Vorbelegung je Feld; `null` heißt „kein Wert", das
  /// Feld bleibt leer — **keine 0**.
  final List<(String, double?)> felder;

  final String fuss;
  final bool Function(List<double> werte) gueltig;
  final Future<void> Function(WidgetRef ref, List<double> werte) sichere;

  @override
  ConsumerState<_ZahlenBlatt> createState() => _ZahlenZustand();
}

class _ZahlenZustand extends ConsumerState<_ZahlenBlatt> {
  late final List<TextEditingController> _felder = [
    for (final (_, wert) in widget.felder)
      TextEditingController(
        text: wert == null ? '' : formatNumber(wert, nachkommastellen: 2),
      ),
  ];

  bool _laeuft = false;

  @override
  void initState() {
    super.initState();
    for (final f in _felder) {
      f.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final f in _felder) {
      f.dispose();
    }
    super.dispose();
  }

  /// Die Werte, oder `null`, wenn eines der Felder keine Zahl trägt.
  List<double>? get _werte {
    final werte = <double>[];
    for (final f in _felder) {
      final text = f.text.trim();
      // Steht ein Komma da, ist es das Dezimalzeichen und ein Punkt der
      // Tausendertrenner („1.240,50"); sonst ist der Punkt das
      // Dezimalzeichen („0.75").
      final roh = text.contains(',')
          ? text.replaceAll('.', '').replaceAll(',', '.')
          : text;
      final zahl = double.tryParse(roh);
      if (zahl == null) return null;
      werte.add(zahl);
    }
    return widget.gueltig(werte) ? werte : null;
  }

  Future<void> _sichere(List<double> werte) async {
    setState(() => _laeuft = true);
    await widget.sichere(ref, werte);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final werte = _werte;
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    return KiBlatt(
      titel: widget.titel,
      abbrechen: KiLeistenKnopf(
        titel: 'Abbrechen',
        onPressed: _laeuft ? null : () => Navigator.of(context).pop(),
      ),
      rechts: KiLeistenKnopf(
        titel: 'Sichern',
        onPressed: _laeuft || werte == null ? null : () => _sichere(werte),
      ),
      inhalt: [
        const SizedBox(height: 14),
        KiFormKarte(
          zeilen: [
            for (var i = 0; i < _felder.length; i++)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                child: Row(
                  children: [
                    Text(widget.felder[i].$1),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CupertinoTextField.borderless(
                        controller: _felder[i],
                        autofocus: i == 0,
                        textAlign: TextAlign.end,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: TextStyle(color: river),
                      ),
                    ),
                    Text(' \$', style: TextStyle(color: muted)),
                  ],
                ),
              ),
          ],
        ),
        KiFormFuss(widget.fuss),
      ],
    );
  }
}
