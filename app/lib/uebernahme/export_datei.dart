// Die Naht zur Dateiauswahl (#59 Teil 1) — `ExportDateiWaehler`. Der Schirm
// „Daten übernehmen" (`uebernahme_view.dart`) kennt nur diese Schnittstelle,
// nie `file_picker` selbst; im Test steht an ihrer Stelle ein Fake
// (`app/test/uebernahme/uebernahme_support.dart`, `FakeWaehler`). Dieselbe
// Bauart wie `StrichcodeLeser` und `FotoKamera`.
//
// API und Vertrag sind durch `app/test/uebernahme/uebernahme_support.dart`
// verbindlich vorgegeben — diese Datei darf die Tests ausführen, aber nicht
// verändern (`CLAUDE.md`).
//
// **Die App verändert und löscht die gewählte Datei nie.** Sie ist bis zur
// Abnahme Tims zweite Kopie seiner Gym-Trainings. Auf iOS öffnet `file_picker`
// den Systemwähler mit `asCopy`: Gelesen wird eine **Kopie** im
// temporären Verzeichnis, und nur diese Kopie räumt [DateiAuswahl] nach dem
// Lesen ab. Das Original in „Dateien" bleibt unberührt.
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Eine gewählte Datei: ihr Name und ihr Inhalt, ganz gelesen.
class ExportDatei {
  const ExportDatei({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Die Dateiauswahl, wie der Schirm sie sieht.
abstract class ExportDateiWaehler {
  /// Öffnet die Dateiauswahl des Systems. `null` heißt: abgebrochen.
  Future<ExportDatei?> waehle();
}

/// Die echte Auswahl — `file_picker`, auf iOS über
/// `UIDocumentPickerViewController`. Braucht auf iOS weder eine Capability
/// noch ein Entitlement noch einen Freigabetext: Der Systemwähler läuft
/// außerhalb der App, und sie bekommt nur die Datei, die Tim antippt.
class DateiAuswahl implements ExportDateiWaehler {
  const DateiAuswahl();

  @override
  Future<ExportDatei?> waehle() async {
    // `FileType.any`, nicht `custom` mit „json": Eine Datei, die auf dem
    // Weg in „Dateien" ihre Endung verloren hat, soll sich noch wählen
    // lassen. Eine falsche Datei lehnt der Leser mit Namen ab.
    final datei = await FilePicker.pickFile();
    if (datei == null) return null;
    try {
      return ExportDatei(name: datei.name, bytes: await datei.readAsBytes());
    } finally {
      // Die Kopie im temporären Verzeichnis des Wählers, nicht das Original.
      await FilePicker.clearTemporaryFiles();
    }
  }
}

/// Die Naht im Riverpod-Baum. In Tests mit
/// `exportDateiWaehlerProvider.overrideWithValue(FakeWaehler())` ersetzt —
/// sonst öffnete der Vorgabewert den echten Systemwähler.
final exportDateiWaehlerProvider = Provider<ExportDateiWaehler>(
  (ref) => const DateiAuswahl(),
);
