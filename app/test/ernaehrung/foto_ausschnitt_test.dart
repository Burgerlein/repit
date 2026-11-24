import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:repit/ernaehrung/foto_ausschnitt.dart';
import 'package:repit/ernaehrung/foto_kamera.dart';

/// Tests für den **Zuschnitt auf den Sucher-Rahmen** (#391, Tim,
/// 05.11.2026): Seit #353 stand im Prüfblatt das ganze Hochkantfoto. Gemeint
/// war nur, was im **Rahmen** der KI-Kamera steht — dieser Ausschnitt geht
/// an Gemini und steht im Prüfblatt, im Seitenverhältnis des Rahmens.
///
/// ## Die Naht — Festlegung des Agenten von #391, **nicht von Tim**
///
/// ```dart
/// // lib/ernaehrung/foto_ausschnitt.dart
/// class SucherAusschnitt {
///   const SucherAusschnitt({
///     required Size fenster,   // das Sucherfenster, in Punkten
///     required Rect rahmen,    // der Rahmen darin, in Punkten
///     double? vorschau,        // Breite / Höhe der Vorschau, wie gezeigt
///   });
///   BildRechteck imBild(int breite, int hoehe);
/// }
/// typedef BildRechteck = ({int x, int y, int breite, int hoehe});
///
/// // lib/ernaehrung/foto_kamera.dart
/// List<int> verkleinere(List<int> jpeg, {SucherAusschnitt? ausschnitt});
/// ```
///
/// **Die Annahme über die Vorschau:** Sie füllt das Fenster mit
/// `BoxFit.cover`, mittig — so baut sie `_GeraeteSucher`. Ohne [vorschau]
/// hat sie das Seitenverhältnis des Fotos; mit [vorschau] zeigt sie den
/// mittigen Ausschnitt des Fotos in diesem Seitenverhältnis (eine
/// 16 : 9-Vorschau über einem 4 : 3-Foto). Breite und Höhe an
/// `imBild` sind die des **gedrehten** Bildes — `verkleinere` dreht nach
/// EXIF, bevor es schneidet.
///
/// Die Zahlen sind von Hand gerechnet und so gewählt, dass sie aufgehen.
void main() {
  /// Ein Rahmen der Größe [w] × [h] mit Mittelpunkt [mitte].
  Rect rahmen(Offset mitte, double w, double h) =>
      Rect.fromCenter(center: mitte, width: w, height: h);

  // ═════════════════════════════════════════════════════════════════════
  group('SucherAusschnitt.imBild — die Rechnung', () {
    test(
      'Hochformat in einem breiteren Fenster: oben und unten beschnitten',
      () {
        // Foto 1000 × 2000, Fenster 400 × 300. `cover`: Faktor
        // max(400/1000, 300/2000) = 0,4 → gezeigt 400 × 800, 250 Punkte oben
        // und unten abgeschnitten. Rahmen 200 × 200 in der Mitte (200, 150)
        // → links 100, oben 50 → im Bild (250, 750), Kante 500.
        final a = SucherAusschnitt(
          fenster: const Size(400, 300),
          rahmen: rahmen(const Offset(200, 150), 200, 200),
        );
        expect(a.imBild(1000, 2000), (x: 250, y: 750, breite: 500, hoehe: 500));
      },
    );

    test('Querformat in einem schmaleren Fenster: links und rechts '
        'beschnitten', () {
      // Foto 3000 × 1000, Fenster 400 × 200. Faktor max(400/3000, 200/1000)
      // = 0,2 → gezeigt 600 × 200, links 100 Punkte abgeschnitten. Rahmen
      // 100 × 100 um (200, 100) → links 150, oben 50 → im Bild
      // ((150 + 100) / 0,2, 50 / 0,2) = (1250, 250), Kante 500.
      final a = SucherAusschnitt(
        fenster: const Size(400, 200),
        rahmen: rahmen(const Offset(200, 100), 100, 100),
      );
      expect(a.imBild(3000, 1000), (x: 1250, y: 250, breite: 500, hoehe: 500));
    });

    test('ein Rahmen, der nicht mittig sitzt, wird an seiner Stelle '
        'geschnitten', () {
      // Wie im Sucher bei 46 % der Höhe: Mitte (200, 138) in 400 × 300 →
      // oben 38 → im Bild (38 + 250) / 0,4 = 720.
      final a = SucherAusschnitt(
        fenster: const Size(400, 300),
        rahmen: rahmen(const Offset(200, 138), 200, 200),
      );
      expect(a.imBild(1000, 2000), (x: 250, y: 720, breite: 500, hoehe: 500));
    });

    test('der Ausschnitt hat das Seitenverhältnis des Rahmens', () {
      // Rahmen 200 × 100 → im Bild 500 × 250.
      final a = SucherAusschnitt(
        fenster: const Size(400, 300),
        rahmen: rahmen(const Offset(200, 150), 200, 100),
      );
      final r = a.imBild(1000, 2000);
      expect(r, (x: 250, y: 875, breite: 500, hoehe: 250));
    });

    test('eine Vorschau in anderem Format als das Foto: zuerst ihr '
        'mittiger Ausschnitt, dann `cover`', () {
      // Foto 3000 × 4000 (3 : 4), Vorschau 9 : 16 → sie zeigt die mittigen
      // 2250 × 4000 (375 links und rechts weg). Fenster 450 × 300: Faktor
      // max(450/2250, 300/4000) = 0,2 → gezeigt 450 × 800, oben 250 weg.
      // Rahmen 200 × 200 um (225, 150) → links 125, oben 50 → im Bild
      // (375 + 125 / 0,2, (50 + 250) / 0,2) = (1000, 1500), Kante 1000.
      final a = SucherAusschnitt(
        fenster: const Size(450, 300),
        rahmen: rahmen(const Offset(225, 150), 200, 200),
        vorschau: 9 / 16,
      );
      expect(a.imBild(3000, 4000), (
        x: 1000,
        y: 1500,
        breite: 1000,
        hoehe: 1000,
      ));
    });

    test('ohne Angabe zur Vorschau gilt das Format des Fotos', () {
      // Dasselbe ohne `vorschau`: Faktor max(450/3000, 300/4000) = 0,15 —
      // ein anderer, größerer Ausschnitt. Gegenprobe zum Fall davor.
      final a = SucherAusschnitt(
        fenster: const Size(450, 300),
        rahmen: rahmen(const Offset(225, 150), 200, 200),
      );
      final r = a.imBild(3000, 4000);
      expect(r.breite, closeTo(1333, 1));
      expect(r.hoehe, closeTo(1333, 1));
    });

    test('ein Rahmen, der über das Fenster ragt, bleibt im Bild', () {
      final a = SucherAusschnitt(
        fenster: const Size(400, 300),
        rahmen: const Rect.fromLTWH(-50, -50, 600, 500),
      );
      final r = a.imBild(1000, 2000);
      expect(r.x, greaterThanOrEqualTo(0));
      expect(r.y, greaterThanOrEqualTo(0));
      expect(r.x + r.breite, lessThanOrEqualTo(1000));
      expect(r.y + r.hoehe, lessThanOrEqualTo(2000));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('verkleinere mit Ausschnitt', () {
    img.Image lies(List<int> bytes) {
      final bild = img.decodeJpg(Uint8List.fromList(bytes));
      expect(bild, isNotNull, reason: 'heraus kommt ein lesbares JPEG');
      return bild!;
    }

    List<int> jpeg(int breite, int hoehe) => img.encodeJpg(
      img.Image(width: breite, height: hoehe)
        ..clear(img.ColorRgb8(180, 120, 60)),
    );

    final mitte = SucherAusschnitt(
      fenster: const Size(400, 300),
      rahmen: Rect.fromCenter(
        center: const Offset(200, 150),
        width: 200,
        height: 200,
      ),
    );

    test('heraus kommt nur der Rahmen, im Seitenverhältnis des Rahmens', () {
      final klein = lies(verkleinere(jpeg(1000, 2000), ausschnitt: mitte));
      expect(klein.width, 500);
      expect(klein.height, 500);
    });

    test('ein großer Ausschnitt wird danach auf 1.024 Punkte verkleinert', () {
      // 3000 × 6000 → Ausschnitt 1500 × 1500 → 1024 × 1024.
      final klein = lies(verkleinere(jpeg(3000, 6000), ausschnitt: mitte));
      expect(klein.width, 1024);
      expect(klein.height, 1024);
    });

    test('ohne Ausschnitt bleibt das ganze Bild', () {
      final klein = lies(verkleinere(jpeg(1000, 2000)));
      expect(klein.width, 512);
      expect(klein.height, 1024);
    });

    test('EXIF-Drehung: geschnitten wird im gedrehten Bild — was im Sucher '
        'oben stand, steht im Ausschnitt', () {
      // Roh quer 400 × 300, EXIF-Orientierung 6 (90° im Uhrzeigersinn zu
      // drehen): Gezeigt wird es hochkant 300 × 400, und die **linke**
      // Hälfte des Rohbilds steht dann **oben**. Links rot, rechts blau.
      final roh = img.Image(width: 400, height: 300);
      for (final p in roh) {
        if (p.x < 200) {
          p
            ..r = 230
            ..g = 20
            ..b = 20;
        } else {
          p
            ..r = 20
            ..g = 20
            ..b = 230;
        }
      }
      roh.exif.imageIfd.orientation = 6;
      final bytes = img.encodeJpg(roh);
      // Voraussetzung: Das JPEG trägt die Drehung. Im Kopf steht es quer;
      // `decodeJpg` rechnet die Drehung beim Lesen selbst ein und liefert
      // es hochkant (und ohne Orientierungs-Tag — deshalb wird hier nicht
      // das Tag geprüft).
      expect(jpegMasse(bytes), (breite: 400, hoehe: 300));
      final gelesen = img.decodeJpg(Uint8List.fromList(bytes))!;
      expect(
        (gelesen.width, gelesen.height),
        (300, 400),
        reason: 'Voraussetzung: das JPEG trägt die Drehung',
      );

      // Fenster im Format des gedrehten Bildes (300 × 400), Rahmen ist die
      // obere Hälfte: 300 × 180 um (150, 100) → im Bild (0, 10, 300, 180).
      final oben = SucherAusschnitt(
        fenster: const Size(300, 400),
        rahmen: Rect.fromCenter(
          center: const Offset(150, 100),
          width: 300,
          height: 180,
        ),
      );
      final klein = lies(verkleinere(bytes, ausschnitt: oben));
      expect(klein.width, 300, reason: 'Breite des gedrehten Bildes');
      expect(klein.height, 180);
      for (final (x, y) in const [(150, 90), (10, 10), (290, 170)]) {
        final p = klein.getPixel(x, y);
        expect(
          p.r > 150 && p.b < 100,
          isTrue,
          reason:
              'bei ($x, $y) rot erwartet (obere Hälfte des gedrehten Bildes), '
              'war r=${p.r} b=${p.b}',
        );
      }
      expect(
        klein.exif.imageIfd.orientation,
        anyOf(isNull, 1),
        reason: 'die Drehung steckt im Bild, nicht mehr in EXIF',
      );
    });
  });
}
