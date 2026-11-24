// Die Naht zur Kamera (#324) — `StrichcodeLeser`. Der Kamera-Schirm
// (`kamera_seite.dart`) kennt nur diese Schnittstelle, nie
// `mobile_scanner` selbst; im Test steht an ihrer Stelle `TestLeser`
// (`app/test/ernaehrung/kamera_attrappe.dart`).
//
// API und Vertrag sind durch `app/test/ernaehrung/barcode_kamera_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf, „Die Naht zur Kamera") —
// diese Datei darf die Tests ausführen, aber nicht verändern (`CLAUDE.md`,
// „Wer Tests schreibt, schreibt nicht die Implementierung").
//
// **Ein Widget-Bauer, kein Stream.** Die Kamera läuft, solange ihre
// Vorschau im Baum steht, und hört auf, wenn sie verschwindet — dieselbe
// Form, die `MobileScanner` selbst hat.
//
// **`aufCode` meldet roh**, jedes Bild. Die Kamera sieht dieselbe Packung
// dreißigmal in der Sekunde; dass ein Code je Sitzung einmal ausgewertet
// wird, ist Sache des Schirms, nicht dieser Naht.
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'kamera_bausteine.dart';

/// Die Kamera, wie der Kamera-Schirm sie sieht.
abstract interface class StrichcodeLeser {
  /// Die Kameravorschau. Meldet jeden erkannten Code über [aufCode] und
  /// eine verweigerte Kamerafreigabe über [aufVerweigert].
  Widget sucher({
    required ValueChanged<String> aufCode,
    required VoidCallback aufVerweigert,
  });

  /// Öffnet die Einstellungen dieser App (Kamerafreigabe).
  Future<void> oeffneEinstellungen();
}

/// Die echte Kamera — `mobile_scanner`, auf iOS über Apples
/// Vision-Framework. **Kein Bild wird gespeichert oder verschickt**:
/// `returnImage` bleibt aus, und aus der Vorschau geht nur der gelesene
/// Strichcode als Text heraus — die Hälfte der Zusage aus
/// `NSCameraUsageDescription` (`ios/Runner/Info.plist`), die den
/// Barcode-Weg betrifft. Die andere Hälfte, das Foto für die
/// KI-Schätzung, hält `ki_sucher.dart`.
class KameraLeser implements StrichcodeLeser {
  const KameraLeser();

  /// Der Kanal zu `AppDelegate.swift`, der die Einstellungen dieser App
  /// öffnet. `mobile_scanner` kann das nicht, und ein eigenes Paket nur
  /// für eine Zeile Swift wäre zu viel.
  static const _einstellungen = MethodChannel(
    'de.rosenbach.repit/einstellungen',
  );

  @override
  Widget sucher({
    required ValueChanged<String> aufCode,
    required VoidCallback aufVerweigert,
  }) => _KameraSucher(aufCode: aufCode, aufVerweigert: aufVerweigert);

  @override
  Future<void> oeffneEinstellungen() =>
      _einstellungen.invokeMethod<void>('oeffne');
}

/// Die Naht im Riverpod-Baum. In Tests mit
/// `strichcodeLeserProvider.overrideWithValue(TestLeser())` ersetzt —
/// sonst baute der Vorgabewert ein echtes `MobileScanner`, und der Test
/// scheiterte am fehlenden Plugin.
final strichcodeLeserProvider = Provider<StrichcodeLeser>(
  (ref) => const KameraLeser(),
);

/// Die Vorschau samt Taschenlampe.
///
/// **Der Controller gehört diesem Widget**, nicht dem `MobileScanner`:
/// Nur so kommt die Taschenlampe an ihn heran, und nur so lässt sich die
/// verweigerte Freigabe als Zustand lesen, statt sie aus einem
/// `errorBuilder` heraus zu melden, der während des Bauens läuft.
class _KameraSucher extends StatefulWidget {
  const _KameraSucher({required this.aufCode, required this.aufVerweigert});

  final ValueChanged<String> aufCode;
  final VoidCallback aufVerweigert;

  @override
  State<_KameraSucher> createState() => _KameraSucherZustand();
}

class _KameraSucherZustand extends State<_KameraSucher>
    with WidgetsBindingObserver {
  /// Nur Strichcodes auf Lebensmittelpackungen. Ein QR-Code daneben (auf
  /// derselben Packung nicht selten) würde sonst als „Strichcode
  /// unbekannt" ausgewertet.
  final _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
  );

  bool _verweigertGemeldet = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_pruefeFreigabe);
  }

  /// Meldet die verweigerte Freigabe **einmal** — der Controller meldet
  /// jede Zustandsänderung, die Absage aber gilt für die ganze Sitzung.
  void _pruefeFreigabe() {
    if (_verweigertGemeldet) return;
    final fehler = _controller.value.error;
    if (fehler?.errorCode != MobileScannerErrorCode.permissionDenied) return;
    _verweigertGemeldet = true;
    widget.aufVerweigert();
  }

  /// Mit eigenem Controller übernimmt `MobileScanner` den Lebenszyklus
  /// nicht mehr: Geht die App in den Hintergrund, hält die Kamera hier an,
  /// und beim Zurückkommen läuft sie wieder.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.hasCameraPermission) return;
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_controller.start());
      case AppLifecycleState.inactive:
        unawaited(_controller.stop());
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_pruefeFreigabe);
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: (erfasst) {
            for (final code in erfasst.barcodes) {
              final text = code.rawValue;
              if (text != null && text.isNotEmpty) widget.aufCode(text);
            }
          },
          // Schwarz statt der englischen Fehlermeldung des Pakets: Die
          // Absage benennt der Schirm selbst, auf Deutsch.
          errorBuilder: (_, _) => const ColoredBox(color: Color(0xFF07090A)),
          placeholderBuilder: (_) => const ColoredBox(color: Color(0xFF07090A)),
        ),
        Positioned(left: 12, top: 12, child: _Taschenlampe(_controller)),
      ],
    );
  }
}

/// Die Taschenlampe des Barcode-Lesers — **nur, wenn das Gerät eine hat**.
/// Der Knopf selbst ist [LampenKnopf], derselbe wie im KI-Modus (#347).
class _Taschenlampe extends StatelessWidget {
  const _Taschenlampe(this.controller);

  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: controller,
      builder: (context, zustand, _) {
        final an = zustand.torchState == TorchState.on;
        if (zustand.torchState == TorchState.unavailable) {
          return const SizedBox.shrink();
        }
        return LampenKnopf(
          an: an,
          aufWechsel: () => unawaited(controller.toggleTorch()),
        );
      },
    );
  }
}
