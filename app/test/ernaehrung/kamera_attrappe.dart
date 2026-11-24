import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/ernaehrung/strichcode_leser.dart';

/// Die Kamera im Test (#324) — die Naht `StrichcodeLeser`, von Hand
/// gefüllt. Warum die Naht so aussieht, steht im Kopf von
/// `barcode_kamera_test.dart`.
///
/// Gebraucht von `barcode_kamera_test.dart`, `eintragweg_verdrahtung_test
/// .dart` und `shell/root_view_test.dart`: Jede Hülle, in der der (+)
/// gedrückt werden kann, setzt sie über `strichcodeLeserProvider` ein —
/// sonst baute der Vorgabewert ein echtes `MobileScanner`, und der Test
/// scheiterte am fehlenden Plugin statt an seinem Gegenstand.
///
/// Wie die echte Kamera erkennt sie nur, **solange ihre Vorschau im Baum
/// steht**: [erkenne] ohne Vorschau tut nichts — so wie eine Kamera, die
/// abgebaut ist, nichts mehr sieht.
///
/// Geschrieben vom Test-Agenten von #324; Tim hat sie nicht gesehen.
class TestLeser implements StrichcodeLeser {
  _TestSucherZustand? _aktiv;

  /// Wie oft der Weg in die Einstellungen genommen wurde.
  int einstellungenGeoeffnet = 0;

  /// Ob gerade eine Vorschau im Baum steht.
  bool get laeuft => _aktiv != null;

  @override
  Widget sucher({
    required ValueChanged<String> aufCode,
    required VoidCallback aufVerweigert,
  }) => _TestSucher(
    leser: this,
    aufCode: aufCode,
    aufVerweigert: aufVerweigert,
  );

  @override
  Future<void> oeffneEinstellungen() async => einstellungenGeoeffnet++;

  /// Ein Bild, in dem [code] erkannt wird — roh, wie von `onDetect`.
  void erkenne(String code) => _aktiv?.widget.aufCode(code);

  /// Die Kamerafreigabe ist verweigert.
  void verweigere() {
    final aktiv = _aktiv;
    if (aktiv == null) fail('keine Vorschau im Baum, die es melden könnte');
    aktiv.widget.aufVerweigert();
  }
}

class _TestSucher extends StatefulWidget {
  const _TestSucher({
    required this.leser,
    required this.aufCode,
    required this.aufVerweigert,
  });

  final TestLeser leser;
  final ValueChanged<String> aufCode;
  final VoidCallback aufVerweigert;

  @override
  State<_TestSucher> createState() => _TestSucherZustand();
}

class _TestSucherZustand extends State<_TestSucher> {
  @override
  void initState() {
    super.initState();
    widget.leser._aktiv = this;
  }

  @override
  void dispose() {
    if (identical(widget.leser._aktiv, this)) widget.leser._aktiv = null;
    super.dispose();
  }

  // Feste Größe: Die echte Vorschau füllt, was sie bekommt; eine feste
  // Größe passt in jede Anordnung, auch in eine ohne Grenzen.
  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 300, height: 160);
}
