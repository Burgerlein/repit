// Mahlzeit und Uhrzeit eines Eintrags wählen — **eine Stelle für beide
// Blätter**, die buchen: das Buchungsblatt (#285) und das Prüfblatt der
// Foto-Schätzung (#341). `erfassen.js` zeichnet in beiden dieselbe Karte
// (`menuPick('Mahlzeit', …) + formRow('Uhrzeit', …)`); zwei Fassungen
// derselben Auswahl liefen auseinander.
import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/palette.dart';

/// Die Beschriftungen der vier Mahlzeiten — **in der View, nicht im
/// Kern** (`CLAUDE.md`: Deutsch in der Oberfläche, Englisch im Code).
String mahlzeitText(Mahlzeit mahlzeit) => switch (mahlzeit) {
  Mahlzeit.fruehstueck => 'Frühstück',
  Mahlzeit.mittag => 'Mittagessen',
  Mahlzeit.snack => 'Snack',
  Mahlzeit.abend => 'Abendessen',
};

/// `HH:mm` einer Berliner Wanduhrzeit in Minuten seit Mitternacht.
String uhrzeitText(int minutenSeitMitternacht) {
  final stunde = (minutenSeitMitternacht ~/ Duration.minutesPerHour)
      .toString()
      .padLeft(2, '0');
  final minute = (minutenSeitMitternacht % Duration.minutesPerHour)
      .toString()
      .padLeft(2, '0');
  return '$stunde:$minute';
}

/// Die Auswahl der Mahlzeit; `null` nach „Abbrechen".
Future<Mahlzeit?> waehleMahlzeit(BuildContext context) =>
    showCupertinoModalPopup<Mahlzeit>(
      context: context,
      builder: (blattKontext) => CupertinoActionSheet(
        title: const Text('Mahlzeit'),
        actions: [
          for (final mahlzeit in Mahlzeit.values)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(blattKontext, mahlzeit),
              child: Text(mahlzeitText(mahlzeit)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(blattKontext),
          child: const Text('Abbrechen'),
        ),
      ),
    );

/// Das Rad für die Uhrzeit, vorbelegt mit [minutenSeitMitternacht]. Gibt
/// zurück, was beim Schließen eingestellt ist.
Future<int> waehleUhrzeit(
  BuildContext context,
  int minutenSeitMitternacht,
) async {
  var minuten = minutenSeitMitternacht;
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (blattKontext) => Container(
      height: 240,
      color: CupertinoDynamicColor.resolve(Palette.bg, blattKontext),
      child: SafeArea(
        top: false,
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.time,
          use24hFormat: true,
          minuteInterval: 5,
          // Der Kalendertag im Träger ist beliebig und wird nie gelesen:
          // Gewählt wird eine **Uhrzeit**, kein Zeitpunkt. Welcher Tag
          // gemeint ist, weiß der Aufrufer.
          initialDateTime: DateTime.utc(
            2000,
            1,
            1,
            minuten ~/ Duration.minutesPerHour,
            (minuten % Duration.minutesPerHour) ~/ 5 * 5,
          ),
          onDateTimeChanged: (wert) =>
              minuten = wert.hour * Duration.minutesPerHour + wert.minute,
        ),
      ),
    ),
  );
  return minuten;
}
