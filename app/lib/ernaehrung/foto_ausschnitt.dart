// Der Zuschnitt des KI-Fotos auf den Sucher-Rahmen (#391, Tim,
// 05.11.2026): An Gemini und ins Prüfblatt geht nur, was im **Rahmen**
// der KI-Kamera stand — nicht das ganze Hochkantfoto, das seit #353 im
// Prüfblatt stand.
//
// Verhalten durch `app/test/ernaehrung/foto_ausschnitt_test.dart`
// vorgegeben — diese Datei darf die Tests ausführen, aber nicht verändern
// (`CLAUDE.md`).
//
// Reine Rechnung ohne Zustand: Sie läuft mit `verkleinere` im Isolate
// (`foto_kamera.dart`), deshalb nur Werttypen aus `dart:ui`.
import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart';

/// Ein Rechteck in Bildpunkten.
typedef BildRechteck = ({int x, int y, int breite, int hoehe});

/// Wo der Rahmen stand, als ausgelöst wurde — in Punkten des Suchers.
///
/// **Die Annahme über die Vorschau:** Sie füllt das [fenster] mit
/// `BoxFit.cover`, mittig, so wie `_GeraeteSucher` sie baut. Ohne
/// [vorschau] hat sie das Format des Fotos; mit [vorschau] zeigt sie den
/// mittigen Ausschnitt des Fotos in diesem Format — eine 16 : 9-Vorschau
/// über einem 4 : 3-Foto schneidet links und rechts ab, bevor das Fenster
/// noch einmal beschneidet.
@immutable
class SucherAusschnitt {
  const SucherAusschnitt({
    required this.fenster,
    required this.rahmen,
    this.vorschau,
  });

  /// Das Sucherfenster.
  final Size fenster;

  /// Der Rahmen im [fenster].
  final Rect rahmen;

  /// Breite durch Höhe der Vorschau, so wie sie gezeigt wird (hochkant).
  final double? vorschau;

  /// Der Rahmen im Bild der Größe [breite] × [hoehe] — **nach** der
  /// EXIF-Drehung, also im Bild, wie es gezeigt wird. Bleibt im Bild,
  /// auch wenn [rahmen] über das Fenster ragt.
  BildRechteck imBild(int breite, int hoehe) {
    // Was die Vorschau vom Foto zeigt: das ganze Foto oder seinen mittigen
    // Ausschnitt im Format der Vorschau.
    var sichtB = breite.toDouble();
    var sichtH = hoehe.toDouble();
    final v = vorschau;
    if (v != null && v > 0) {
      if (sichtB / sichtH > v) {
        sichtB = sichtH * v;
      } else {
        sichtH = sichtB / v;
      }
    }
    final sichtX = (breite - sichtB) / 2;
    final sichtY = (hoehe - sichtH) / 2;

    // `BoxFit.cover`, mittig: der größere der beiden Faktoren.
    final faktor = math.max(fenster.width / sichtB, fenster.height / sichtH);
    final versatzX = (fenster.width - sichtB * faktor) / 2;
    final versatzY = (fenster.height - sichtH * faktor) / 2;

    final links = sichtX + (rahmen.left - versatzX) / faktor;
    final oben = sichtY + (rahmen.top - versatzY) / faktor;
    final rechts = sichtX + (rahmen.right - versatzX) / faktor;
    final unten = sichtY + (rahmen.bottom - versatzY) / faktor;

    final x = links.round().clamp(0, breite - 1);
    final y = oben.round().clamp(0, hoehe - 1);
    final x2 = rechts.round().clamp(x + 1, breite);
    final y2 = unten.round().clamp(y + 1, hoehe);
    return (x: x, y: y, breite: x2 - x, hoehe: y2 - y);
  }

  @override
  bool operator ==(Object other) =>
      other is SucherAusschnitt &&
      other.fenster == fenster &&
      other.rahmen == rahmen &&
      other.vorschau == vorschau;

  @override
  int get hashCode => Object.hash(fenster, rahmen, vorschau);
}
