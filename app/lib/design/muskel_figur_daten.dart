// ERZEUGT von `scripts/figure-data-to-dart.mjs` aus
// `docs/screens/figure-data.js` — **nicht von Hand ändern**; wer die Pfade
// ändern will, ändert die Quelle und erzeugt neu:
//
//   node scripts/figure-data-to-dart.mjs
//   node scripts/figure-data-to-dart.mjs --pruefen   # prüft, ob sie passen
//
// Die Pfade stammen aus unserem eigenen Code (`MuscleFigureData.swift`, dort
// aus dem eigenen Dashboard) — kein Fremdmaterial, keine Lizenzfrage.
//
// Entwurfsgitter: 200 breit, 432 hoch, **eine** Körperhälfte; die andere
// entsteht durch Spiegelung. `muskel: null` heißt Haut ohne Zuordnung, sonst
// steht der deutsche Name aus `Muscle.german`. Ein Pfad ist eine flache
// Befehlsliste: `[0, x, y]` = Move, `[1, x, y]` = Line,
// `[2, x1, y1, x2, y2, x, y]` = Cubic, `[3]` = Close, alles absolut.
//
// dart format off

/// Ein Pfad der Figur: der Muskel, zu dem er gehört (`null` = Haut), und seine
/// Befehle.
typedef FigurTeil = ({String? muskel, List<double> pfad});

/// Der Kopf: Mittelpunkt x, y und die Halbachsen.
const List<double> kFigurKopf = [100, 33, 15.5, 19.5];

/// Der Umriss des Rumpfes (Haut).
const List<List<double>> kFigurUmriss = [
  [0, 91, 46, 1, 109, 46, 2, 110, 54, 112, 60, 116, 64, 1, 84, 64, 2, 88, 60, 90, 54, 91, 46, 3],
  [0, 100, 60, 2, 86, 60, 72, 64, 60, 72, 2, 52, 78, 51, 90, 54, 102, 2, 58, 116, 62, 130, 64, 146, 2, 65, 160, 64, 170, 64, 180, 2, 64, 194, 68, 206, 78, 214, 1, 100, 224, 1, 122, 214, 2, 132, 206, 136, 194, 136, 180, 2, 136, 170, 135, 160, 136, 146, 2, 138, 130, 142, 116, 146, 102, 2, 149, 90, 148, 78, 140, 72, 2, 128, 64, 114, 60, 100, 60, 3],
];

/// Das Bein (Haut).
const List<List<double>> kFigurBein = [
  [0, 66, 200, 2, 59, 222, 59, 250, 63, 274, 2, 65, 288, 69, 298, 73, 306, 1, 95, 306, 2, 97, 284, 99, 256, 99, 230, 1, 99, 214, 3],
  [0, 71, 300, 2, 66, 318, 66, 342, 69, 364, 2, 70, 376, 72, 386, 73, 394, 1, 89, 394, 2, 91, 378, 95, 352, 96, 328, 2, 97, 316, 96, 306, 95, 300, 3],
  [0, 72, 392, 2, 65, 398, 63, 406, 67, 411, 1, 92, 411, 2, 94, 404, 92, 398, 89, 392, 3],
];

/// Der Arm (Haut), um die Schulter gedreht gezeichnet.
const List<List<double>> kFigurArm = [
  [0, 56, 74, 2, 43, 77, 35, 90, 35, 106, 2, 34, 124, 33, 142, 35, 160, 1, 50, 162, 2, 52, 146, 54, 130, 57, 114, 2, 59, 100, 61, 86, 56, 74, 3],
  [0, 35, 156, 2, 30, 170, 27, 188, 25, 206, 2, 24, 214, 24, 220, 25, 226, 1, 34, 228, 2, 38, 214, 42, 198, 46, 182, 2, 48, 172, 50, 164, 50, 158, 3],
  [0, 25, 224, 2, 18, 230, 14, 240, 16, 250, 2, 20, 256, 30, 253, 33, 244, 2, 35, 238, 35, 232, 34, 226, 3],
];

/// Die Muskeln des Arms von vorne.
const List<FigurTeil> kFigurArmVorne = [
  (muskel: 'Seitliche Schulter', pfad: [0, 57, 75, 2, 45, 79, 37, 91, 37, 105, 2, 38, 111, 41, 115, 45, 117, 2, 45, 104, 48, 92, 61, 81, 3]),
  (muskel: 'Vordere Schulter', pfad: [0, 64, 72, 2, 53, 75, 46, 85, 45, 99, 2, 47, 106, 51, 110, 56, 112, 2, 59, 100, 63, 90, 72, 79, 3]),
  (muskel: 'Bizeps', pfad: [0, 54, 110, 2, 44, 116, 38, 131, 38, 147, 2, 40, 156, 46, 159, 52, 155, 2, 56, 141, 58, 125, 58, 112, 3]),
  (muskel: 'Unterarme', pfad: [0, 44, 160, 2, 36, 172, 31, 188, 30, 204, 2, 33, 208, 37, 207, 39, 202, 2, 43, 190, 47, 176, 50, 163, 3]),
  (muskel: 'Unterarme', pfad: [0, 38, 158, 2, 32, 168, 28, 180, 27, 194, 2, 28, 198, 31, 198, 32, 194, 2, 34, 182, 38, 170, 42, 160, 3]),
];

/// Die Muskeln des Arms von hinten.
const List<FigurTeil> kFigurArmHinten = [
  (muskel: 'Seitliche Schulter', pfad: [0, 57, 75, 2, 45, 79, 37, 91, 37, 105, 2, 38, 111, 41, 115, 45, 117, 2, 45, 104, 48, 92, 61, 81, 3]),
  (muskel: 'Hintere Schulter', pfad: [0, 64, 74, 2, 53, 77, 46, 86, 43, 97, 2, 45, 104, 50, 108, 55, 110, 2, 58, 99, 63, 90, 72, 81, 3]),
  (muskel: 'Trizeps', pfad: [0, 55, 109, 2, 46, 115, 40, 129, 39, 145, 2, 41, 154, 47, 157, 52, 152, 2, 55, 138, 58, 123, 58, 111, 3]),
  (muskel: 'Unterarme', pfad: [0, 44, 160, 2, 36, 172, 31, 188, 30, 204, 2, 33, 208, 37, 207, 39, 202, 2, 43, 190, 47, 176, 50, 163, 3]),
  (muskel: 'Unterarme', pfad: [0, 38, 158, 2, 32, 168, 28, 180, 27, 194, 2, 28, 198, 31, 198, 32, 194, 2, 34, 182, 38, 170, 42, 160, 3]),
];

/// Rumpf und Bein von vorne.
const List<FigurTeil> kFigurRumpfVorne = [
  (muskel: 'Oberer Rücken', pfad: [0, 91, 54, 2, 87, 62, 79, 68, 66, 72, 1, 85, 74, 2, 89, 70, 93, 64, 95, 59, 3]),
  (muskel: 'Brust', pfad: [0, 99, 72, 2, 86, 69, 72, 71, 63, 79, 2, 56, 87, 54, 99, 57, 108, 2, 65, 117, 81, 120, 93, 117, 2, 97, 115, 99, 110, 99, 104, 3]),
  (muskel: 'Rumpf', pfad: [0, 86, 121, 2, 77, 121, 70, 124, 67, 131, 2, 67, 151, 68, 170, 73, 188, 2, 79, 196, 87, 198, 89, 194, 2, 87, 172, 87, 146, 86, 121, 3]),
  (muskel: 'Rumpf', pfad: [0, 99, 120, 1, 90, 121, 2, 88, 126, 88, 131, 90, 136, 1, 99, 136, 3]),
  (muskel: 'Rumpf', pfad: [0, 99, 138, 1, 90, 138, 2, 88, 143, 88, 149, 90, 153, 1, 99, 153, 3]),
  (muskel: 'Rumpf', pfad: [0, 99, 155, 1, 90, 155, 2, 88, 160, 88, 166, 90, 170, 1, 99, 170, 3]),
  (muskel: 'Rumpf', pfad: [0, 99, 172, 1, 90, 172, 2, 89, 182, 91, 194, 99, 206, 3]),
  (muskel: 'Oberschenkel vorne', pfad: [0, 67, 210, 2, 61, 230, 61, 254, 65, 276, 2, 67, 287, 71, 293, 76, 296, 2, 76, 272, 76, 246, 77, 220, 3]),
  (muskel: 'Oberschenkel vorne', pfad: [0, 79, 212, 2, 77, 236, 77, 262, 79, 287, 2, 81, 294, 87, 296, 89, 290, 2, 91, 265, 91, 238, 89, 216, 3]),
  (muskel: 'Oberschenkel vorne', pfad: [0, 90, 262, 2, 90, 277, 90, 291, 92, 300, 2, 96, 300, 98, 292, 98, 282, 2, 98, 274, 96, 265, 90, 262, 3]),
  (muskel: null, pfad: [0, 91, 216, 2, 93, 231, 95, 247, 97, 258, 1, 99, 258, 1, 99, 224, 3]),
  (muskel: 'Waden', pfad: [0, 69, 314, 2, 66, 330, 66, 346, 69, 360, 2, 72, 354, 74, 338, 75, 318, 3]),
  (muskel: 'Schienbein', pfad: [0, 77, 312, 2, 73, 328, 73, 346, 75, 362, 2, 77, 365, 80, 363, 81, 358, 2, 82, 344, 83, 328, 83, 314, 3]),
];

/// Rumpf und Bein von hinten.
const List<FigurTeil> kFigurRumpfHinten = [
  (muskel: 'Oberer Rücken', pfad: [0, 100, 48, 1, 94, 50, 2, 90, 61, 78, 69, 62, 75, 2, 72, 82, 84, 88, 92, 102, 2, 96, 112, 98, 124, 100, 136, 3]),
  (muskel: 'Oberer Rücken', pfad: [0, 90, 100, 2, 84, 94, 76, 90, 67, 88, 2, 63, 96, 63, 104, 67, 110, 2, 75, 114, 85, 114, 92, 110, 3]),
  (muskel: 'Latissimus', pfad: [0, 93, 111, 2, 82, 115, 70, 113, 63, 108, 2, 59, 120, 59, 135, 63, 150, 2, 71, 164, 84, 174, 97, 180, 2, 99, 162, 97, 136, 93, 111, 3]),
  (muskel: 'Unterer Rücken', pfad: [0, 99, 140, 2, 93, 146, 91, 158, 91, 172, 2, 91, 182, 94, 190, 99, 194, 3]),
  (muskel: 'Gesäß', pfad: [0, 99, 192, 2, 86, 189, 72, 193, 65, 205, 2, 61, 217, 64, 231, 73, 237, 2, 84, 242, 95, 239, 99, 233, 3]),
  (muskel: 'Oberschenkel hinten', pfad: [0, 68, 240, 2, 64, 256, 64, 274, 68, 292, 2, 72, 299, 79, 299, 83, 293, 2, 85, 275, 85, 257, 84, 241, 3]),
  (muskel: 'Oberschenkel hinten', pfad: [0, 86, 241, 2, 86, 259, 88, 277, 90, 293, 2, 92, 298, 97, 296, 98, 289, 2, 99, 273, 99, 255, 97, 241, 3]),
  (muskel: 'Waden', pfad: [0, 71, 307, 2, 66, 321, 66, 339, 70, 355, 2, 75, 361, 81, 357, 83, 347, 2, 84, 331, 83, 315, 80, 305, 3]),
];
