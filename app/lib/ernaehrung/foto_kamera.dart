// Die Fotokamera des KI-Sucher (#340): die Naht `FotoKamera`, ihre echte
// Fassung über das Paket `camera` und das Verkleinern des Fotos. Der
// Sucher selbst liegt in `ki_sucher.dart`, das diese Datei weiterreicht.
//
// API und Verhalten sind durch `app/test/ernaehrung/ki_sucher_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`).
//
// **Das Foto liegt nur im Arbeitsspeicher.** `camera` legt jede Aufnahme
// als Temp-Datei ab; sie wird nach dem Einlesen sofort gelöscht (Review
// Focus 6).
import 'dart:async';
import 'dart:io' show File, FileSystemException;
import 'dart:isolate';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import 'foto_ausschnitt.dart';
import 'kamera_bausteine.dart';

export 'foto_ausschnitt.dart';

// ─────────────────────────────────────────────────────────────────────────
// Die Naht zur Fotokamera
// ─────────────────────────────────────────────────────────────────────────

/// Eine Aufnahme, sobald die Vorschau läuft.
abstract interface class FotoAufnahme {
  /// Nimmt ein Foto auf und liefert es **verkleinert** ([verkleinere]).
  /// Die Temp-Datei der Kamera ist danach gelöscht.
  Future<List<int>> nimmAuf();
}

/// Die Fotokamera, wie der KI-Sucher sie sieht — dieselbe Form wie
/// `StrichcodeLeser`: Die Kamera läuft, solange ihre Vorschau im Baum
/// steht.
abstract interface class FotoKamera {
  /// Die Vorschau. Meldet über [aufBereit], sobald aufgenommen werden
  /// kann, und eine verweigerte Freigabe über [aufVerweigert].
  Widget sucher({
    required ValueChanged<FotoAufnahme> aufBereit,
    required VoidCallback aufVerweigert,
  });
}

/// Die Naht im Riverpod-Baum. In Tests durch `TestFotoKamera` ersetzt
/// (`test/ernaehrung/foto_attrappe.dart`).
final fotoKameraProvider = Provider<FotoKamera>((ref) => const GeraeteKamera());

// ─────────────────────────────────────────────────────────────────────────
// Verkleinern
// ─────────────────────────────────────────────────────────────────────────

/// Die längste Kante, die an Gemini geht (Spec, Schritt 2).
const kiKantenlaenge = 1024;

/// JPEG-Qualität des verkleinerten Fotos.
const kiJpegQualitaet = 80;

/// Schneidet ein JPEG auf den [ausschnitt] zu, verkleinert es auf höchstens
/// [kiKantenlaenge] Punkte Kantenlänge und kodiert es mit Qualität
/// [kiJpegQualitaet]. Ein kleineres Bild wird nicht vergrößert.
///
/// **Der Ausschnitt ist der Sucher-Rahmen** (#391): An Gemini und ins
/// Prüfblatt geht nur, was im Rahmen stand, im Seitenverhältnis des
/// Rahmens. Ohne [ausschnitt] bleibt das ganze Bild.
///
/// Die Drehung aus den EXIF-Daten wird ins Bild gerechnet, **bevor**
/// geschnitten wird — der Rahmen liegt im Bild, wie der Sucher es zeigte.
/// **Die EXIF-Daten selbst gehen nicht mit** — an Google geht das Bild,
/// nicht Kamera, Zeitpunkt oder Ort.
///
/// Wirft eine [FormatException], wenn [jpeg] kein lesbares JPEG ist.
///
/// Rein und ohne Zustand — im Betrieb läuft es in `Isolate.run`
/// ([_GeraeteAufnahme]): Ein Foto in reinem Dart zu dekodieren dauert weit
/// über das Frame-Budget von 8,3 ms.
List<int> verkleinere(List<int> jpeg, {SucherAusschnitt? ausschnitt}) {
  final roh = img.decodeJpg(
    jpeg is Uint8List ? jpeg : Uint8List.fromList(jpeg),
  );
  if (roh == null) throw const FormatException('kein lesbares JPEG');
  final gedreht = img.bakeOrientation(roh);
  final r = ausschnitt?.imBild(gedreht.width, gedreht.height);
  final bild = r == null
      ? gedreht
      : img.copyCrop(gedreht, x: r.x, y: r.y, width: r.breite, height: r.hoehe);
  final lang = math.max(bild.width, bild.height);
  final klein = lang <= kiKantenlaenge
      ? bild
      : bild.width >= bild.height
      ? img.copyResize(
          bild,
          width: kiKantenlaenge,
          interpolation: img.Interpolation.average,
        )
      : img.copyResize(
          bild,
          height: kiKantenlaenge,
          interpolation: img.Interpolation.average,
        );
  klein.exif = img.ExifData();
  return img.encodeJpg(klein, quality: kiJpegQualitaet);
}

/// Breite und Höhe eines JPEG, gelesen aus dem Bildkopf (SOF-Marker) —
/// **ohne** das Bild zu dekodieren, also in Mikrosekunden statt Dutzenden
/// Millisekunden. `null`, wenn [jpeg] keinen lesbaren Kopf hat.
///
/// Damit steht das Prüfblatt-Foto vom ersten Bild an im Seitenverhältnis
/// der Aufnahme (#353), statt nach dem Dekodieren aufzuspringen. Die
/// Drehung aus EXIF steht nach [verkleinere] schon im Bild; die Maße im
/// Kopf sind also die gezeigten.
({int breite, int hoehe})? jpegMasse(List<int> jpeg) {
  if (jpeg.length < 4 || jpeg[0] != 0xFF || jpeg[1] != 0xD8) return null;
  var i = 2;
  while (i + 3 < jpeg.length) {
    if (jpeg[i] != 0xFF) return null;
    final marker = jpeg[i + 1];
    // Füllbytes zwischen Markern.
    if (marker == 0xFF) {
      i++;
      continue;
    }
    // Marker ohne Länge: TEM, RST0–7.
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
      i += 2;
      continue;
    }
    // Anfang der Bilddaten oder Ende — kein Rahmenkopf gefunden.
    if (marker == 0xDA || marker == 0xD9) return null;
    final laenge = (jpeg[i + 2] << 8) | jpeg[i + 3];
    // SOF0–SOF15 außer DHT (C4), JPG (C8) und DAC (CC).
    final istRahmen =
        marker >= 0xC0 &&
        marker <= 0xCF &&
        marker != 0xC4 &&
        marker != 0xC8 &&
        marker != 0xCC;
    if (istRahmen) {
      if (i + 8 >= jpeg.length) return null;
      final hoehe = (jpeg[i + 5] << 8) | jpeg[i + 6];
      final breite = (jpeg[i + 7] << 8) | jpeg[i + 8];
      if (breite == 0 || hoehe == 0) return null;
      return (breite: breite, hoehe: hoehe);
    }
    if (laenge < 2) return null;
    i += 2 + laenge;
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────────
// Die echte Kamera
// ─────────────────────────────────────────────────────────────────────────

/// Die Kamera des Geräts über das Paket `camera`.
///
/// **`enableAudio: false`:** Es wird kein Ton aufgenommen, und deshalb
/// fragt `camera_avfoundation` die Mikrofonfreigabe gar nicht erst ab
/// (geprüft an dessen Test `testCreateCamera_requestsOnlyCameraPermission
/// WithAudioDisabled`). `NSMicrophoneUsageDescription` steht deshalb
/// nicht in `Info.plist` — ein Freigabetext ist eine Zusage, und diese
/// gäbe es nicht.
class GeraeteKamera implements FotoKamera {
  const GeraeteKamera();

  @override
  Widget sucher({
    required ValueChanged<FotoAufnahme> aufBereit,
    required VoidCallback aufVerweigert,
  }) => _GeraeteSucher(aufBereit: aufBereit, aufVerweigert: aufVerweigert);
}

class _GeraeteAufnahme implements FotoAufnahme {
  _GeraeteAufnahme(this._controller, this._ausschnitt);

  final CameraController _controller;

  /// Wo der Rahmen im Sucher steht — gelesen erst beim Auslösen, weil sich
  /// das Fenster seit dem Start geändert haben kann. `null`, solange die
  /// Vorschau noch nicht ausgelegt ist; dann bleibt das ganze Bild.
  final SucherAusschnitt? Function() _ausschnitt;

  @override
  Future<List<int>> nimmAuf() async {
    final datei = await _controller.takePicture();
    final Uint8List roh;
    try {
      roh = await datei.readAsBytes();
    } finally {
      // Sofort nach dem Einlesen — auch, wenn das Einlesen scheitert. Das
      // Foto liegt danach nur noch im Arbeitsspeicher (Review Focus 6).
      try {
        await File(datei.path).delete();
      } on FileSystemException catch (_) {
        // Schon weg — das ist das Ziel.
      }
    }
    final ausschnitt = _ausschnitt();
    return Isolate.run(() => verkleinere(roh, ausschnitt: ausschnitt));
  }
}

class _GeraeteSucher extends StatefulWidget {
  const _GeraeteSucher({required this.aufBereit, required this.aufVerweigert});

  final ValueChanged<FotoAufnahme> aufBereit;
  final VoidCallback aufVerweigert;

  @override
  State<_GeraeteSucher> createState() => _GeraeteSucherZustand();
}

class _GeraeteSucherZustand extends State<_GeraeteSucher>
    with WidgetsBindingObserver {
  /// Die Codes, mit denen `camera_avfoundation` eine fehlende Freigabe
  /// meldet.
  static const _verweigerung = {
    'CameraAccessDenied',
    'CameraAccessDeniedWithoutPrompt',
    'CameraAccessRestricted',
  };

  CameraController? _controller;

  /// Zählt die Starts. Ein Start, der zurückkommt, nachdem die Vorschau
  /// abgebaut oder neu gestartet wurde, gibt seinen Controller gleich
  /// wieder frei.
  int _lauf = 0;

  bool _verweigertGemeldet = false;

  /// Ob die Lampe leuchtet (#347). Nach jedem Neustart der Kamera aus.
  bool _lampe = false;

  /// `false`, sobald die Kamera das Umschalten abgelehnt hat — dann hat
  /// das Gerät keine Lampe, und der Knopf verschwindet.
  bool _lampeMoeglich = true;

  /// Die Größe des Sucherfensters beim letzten Auslegen (#391).
  Size? _fenster;

  /// Was beim Auslösen im Rahmen steht (#391): Fenster, Rahmen
  /// ([RahmenMaler.ki]) und das Format der Vorschau, wie sie gezeigt wird.
  SucherAusschnitt? _ausschnitt() {
    final fenster = _fenster;
    final groesse = _controller?.value.previewSize;
    if (fenster == null || fenster.isEmpty) return null;
    return SucherAusschnitt(
      fenster: fenster,
      rahmen: RahmenMaler.ki.rahmenIn(fenster),
      // `previewSize` ist quer angegeben; gezeigt wird hochkant.
      vorschau: groesse == null || groesse.isEmpty
          ? null
          : groesse.height / groesse.width,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_starte());
  }

  Future<void> _starte() async {
    final lauf = ++_lauf;
    final CameraController neu;
    try {
      final kameras = await availableCameras();
      // Ohne Kamera (Simulator) bleibt die Vorschau schwarz und der
      // Auslöser gedämpft.
      if (kameras.isEmpty) return;
      final hinten = kameras.firstWhere(
        (k) => k.lensDirection == CameraLensDirection.back,
        orElse: () => kameras.first,
      );
      neu = CameraController(
        hinten,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
    } on CameraException catch (fehler) {
      _meldeFehler(fehler);
      return;
    }
    try {
      await neu.initialize();
    } on CameraException catch (fehler) {
      unawaited(neu.dispose());
      _meldeFehler(fehler);
      return;
    }
    if (!mounted || lauf != _lauf) {
      unawaited(neu.dispose());
      return;
    }
    // `camera` steht von sich aus auf `FlashMode.auto`. Ausdrücklich aus,
    // damit der Lampenknopf sagt, was ist: Licht gibt es, wenn Tim es
    // einschaltet, und dann als Dauerlicht statt als Blitz — der spiegelt
    // auf Tellern und Folie.
    try {
      await neu.setFlashMode(FlashMode.off);
    } on CameraException catch (_) {
      _lampeMoeglich = false;
    }
    // Das Foto steht so, wie die Vorschau gezeigt wird — hochkant. Sonst
    // läge der Rahmen in einem quer gedrehten Foto an der falschen Stelle
    // (#391).
    try {
      await neu.lockCaptureOrientation(DeviceOrientation.portraitUp);
    } on CameraException catch (_) {
      // Ohne Sperre steht das Foto, wie das Gerät gehalten wird.
    }
    if (!mounted || lauf != _lauf) {
      unawaited(neu.dispose());
      return;
    }
    setState(() {
      _controller = neu;
      _lampe = false;
    });
    widget.aufBereit(_GeraeteAufnahme(neu, _ausschnitt));
  }

  /// Eine fehlende Freigabe wird **einmal** gemeldet; jeder andere Fehler
  /// lässt die Vorschau schwarz und den Auslöser gedämpft.
  void _meldeFehler(CameraException fehler) {
    if (!_verweigerung.contains(fehler.code)) {
      debugPrint('KI-Sucher: Kamera startet nicht (${fehler.code})');
      return;
    }
    if (!mounted || _verweigertGemeldet) return;
    _verweigertGemeldet = true;
    widget.aufVerweigert();
  }

  /// Schaltet die Lampe um. Lehnt die Kamera ab, hat das Gerät keine —
  /// dann verschwindet der Knopf, statt kaputt dazustehen.
  Future<void> _schalteLampe() async {
    final c = _controller;
    if (c == null) return;
    final an = !_lampe;
    try {
      await c.setFlashMode(an ? FlashMode.torch : FlashMode.off);
    } on CameraException catch (_) {
      if (mounted) setState(() => _lampeMoeglich = false);
      return;
    }
    if (mounted && identical(c, _controller)) setState(() => _lampe = an);
  }

  void _halteAn() {
    _lauf++;
    _lampe = false;
    final alt = _controller;
    _controller = null;
    if (alt != null) unawaited(alt.dispose());
  }

  /// Wie in der Anleitung von `camera`: Geht die App in den Hintergrund,
  /// wird die Kamera freigegeben, beim Zurückkommen neu gestartet.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_verweigertGemeldet) return;
    switch (state) {
      case AppLifecycleState.inactive:
        if (_controller != null) setState(_halteAn);
      case AppLifecycleState.resumed:
        if (_controller == null) unawaited(_starte());
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _halteAn();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final groesse = c?.value.previewSize;
    if (c == null || !c.value.isInitialized || groesse == null) {
      return const ColoredBox(color: kameraSchwarz);
    }
    // Die Vorschau füllt das Fenster und wird beschnitten, nicht
    // verzerrt. `previewSize` ist quer angegeben; hochkant getauscht.
    // **Genau diese Annahme trägt der Zuschnitt** ([SucherAusschnitt],
    // #391): `cover`, mittig, im Format der Vorschau.
    return Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
          builder: (context, grenzen) {
            _fenster = grenzen.biggest;
            return ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: groesse.height,
                  height: groesse.width,
                  child: CameraPreview(c),
                ),
              ),
            );
          },
        ),
        // Dieselbe Stelle wie im Barcode-Modus (`strichcode_leser.dart`).
        if (_lampeMoeglich)
          Positioned(
            left: 12,
            top: 12,
            child: LampenKnopf(
              an: _lampe,
              aufWechsel: () => unawaited(_schalteLampe()),
            ),
          ),
      ],
    );
  }
}
