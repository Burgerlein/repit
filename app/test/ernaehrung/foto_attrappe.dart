import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/ernaehrung/ki_sucher.dart';

/// Die Fotokamera im Test (#340) — die Naht `FotoKamera`, von Hand gefüllt.
/// Dasselbe Muster wie `TestLeser` in `kamera_attrappe.dart`: Die Kamera
/// läuft, **solange ihre Vorschau im Baum steht**, und meldet sich erst
/// dann über `aufBereit` mit einer Aufnahme.
///
/// Geschrieben vom Agenten von #340 (ein Agent, Test zuerst — Plan
/// `2026-11-04-ki-zugang.md`, Task 9); Tim hat sie nicht gesehen.
class TestFotoKamera implements FotoKamera {
  _TestFotoSucherZustand? _aktiv;

  /// Ob gerade eine Vorschau im Baum steht.
  bool get laeuft => _aktiv != null;

  /// Wie oft `nimmAuf` gerufen wurde.
  int aufnahmen = 0;

  /// Gesetzt, wartet jede Aufnahme darauf — so lässt sich der Auslöser
  /// während einer laufenden Aufnahme ein zweites Mal antippen.
  Completer<void>? sperre;

  /// Was jede Aufnahme liefert. Erfundene Bytes, kein echtes Bild.
  List<int> bild = const [0xFF, 0xD8, 0x01, 0x02, 0x03, 0xFF, 0xD9];

  @override
  Widget sucher({
    required ValueChanged<FotoAufnahme> aufBereit,
    required VoidCallback aufVerweigert,
  }) => _TestFotoSucher(
    kamera: this,
    aufBereit: aufBereit,
    aufVerweigert: aufVerweigert,
  );

  /// Die Kamerafreigabe ist verweigert.
  void verweigere() {
    final aktiv = _aktiv;
    if (aktiv == null) fail('keine Vorschau im Baum, die es melden könnte');
    aktiv.widget.aufVerweigert();
  }
}

class _TestAufnahme implements FotoAufnahme {
  _TestAufnahme(this.kamera);

  final TestFotoKamera kamera;

  @override
  Future<List<int>> nimmAuf() async {
    kamera.aufnahmen++;
    final s = kamera.sperre;
    if (s != null) await s.future;
    return List<int>.of(kamera.bild);
  }
}

class _TestFotoSucher extends StatefulWidget {
  const _TestFotoSucher({
    required this.kamera,
    required this.aufBereit,
    required this.aufVerweigert,
  });

  final TestFotoKamera kamera;
  final ValueChanged<FotoAufnahme> aufBereit;
  final VoidCallback aufVerweigert;

  @override
  State<_TestFotoSucher> createState() => _TestFotoSucherZustand();
}

class _TestFotoSucherZustand extends State<_TestFotoSucher> {
  @override
  void initState() {
    super.initState();
    widget.kamera._aktiv = this;
    // Wie die echte Kamera: bereit erst nach dem Start, nicht im Bauen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.aufBereit(_TestAufnahme(widget.kamera));
    });
  }

  @override
  void dispose() {
    if (identical(widget.kamera._aktiv, this)) widget.kamera._aktiv = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 300, height: 160);
}
