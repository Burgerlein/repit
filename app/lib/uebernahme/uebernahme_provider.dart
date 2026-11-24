// Der Stand des Schirms „Daten übernehmen" (#59 Teil 1, mit #482) — **im
// Provider, nicht im Widget.** Das Ergebnis des letzten Laufs steht nach dem
// Zurücknavigieren und nach dem Neuöffnen des Schirms wieder da (Fehler
// `32`); ein `StatefulWidget` hätte es mit dem Schirm weggeworfen.
//
// **`Messwert<T>` gilt hier nicht:** Das ist keine Auswertung aus Apple
// Health, sondern ein Lauf, den Tim selbst anstößt. Es gibt fünf Zustände,
// und `UebernahmeLaeuft` ist keiner, in dem eine Zahl stehen darf — „0
// Trainings in der Datei" behauptete, die Datei sei leer gewesen (Fehler
// `01`).
//
// Spec: `docs/superpowers/specs/2026-11-11-gym-uebernahme-design.md`,
// Abschnitte 7 und 9.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/gym_repository.dart';
import '../data/umfaenge_repository.dart';
import '../gym/gym_verlauf_provider.dart' show gymSitzungenProvider;
import '../koerper/umfaenge_provider.dart'
    show
        umfaengeLetzterMesstagProvider,
        umfaengeMessungenProvider,
        umfangsFormularLaufProvider;
import 'export_datei.dart';
import 'trainingsexport_uebernahme.dart';

/// Wo der Schirm steht. Der `switch` darüber muss vollständig sein.
sealed class UebernahmeStand {
  const UebernahmeStand();
}

/// Vor dem ersten Lauf.
final class UebernahmeLeer extends UebernahmeStand {
  const UebernahmeLeer();
}

/// Die Datei ist gewählt und wird gelesen und geschrieben.
final class UebernahmeLaeuft extends UebernahmeStand {
  const UebernahmeLaeuft();
}

/// Ein Lauf ist durch. Eine `0` in [ergebnis] ist eine Antwort.
final class UebernahmeFertig extends UebernahmeStand {
  const UebernahmeFertig(this.ergebnis);

  final TrainingsexportUebernommen ergebnis;
}

/// Die Datei wurde nicht gelesen. **Nichts ist geschrieben.**
final class UebernahmeAbgelehnt extends UebernahmeStand {
  const UebernahmeAbgelehnt(this.grund);

  final ExportRejection grund;
}

/// Die Ablage (oder die Dateiauswahl) ist gescheitert. Die Übernahme läuft
/// in einer Transaktion: Es steht nichts da, und ein zweiter Versuch geht.
final class UebernahmeGescheitert extends UebernahmeStand {
  const UebernahmeGescheitert(this.fehler);

  final Object fehler;
}

class UebernahmeNotifier extends Notifier<UebernahmeStand> {
  /// Auch die Dateiauswahl zählt: Während sie offen ist, ist der Stand noch
  /// [UebernahmeLeer] (oder der des letzten Laufs), ein zweiter Tipp soll
  /// trotzdem keinen zweiten Wähler öffnen.
  bool _beschaeftigt = false;

  @override
  UebernahmeStand build() => const UebernahmeLeer();

  /// Wählt eine Datei und übernimmt sie. Bricht Tim die Auswahl ab, ändert
  /// sich nichts. Läuft schon eine Übernahme, passiert nichts.
  Future<void> waehleUndUebernimm() async {
    if (_beschaeftigt || state is UebernahmeLaeuft) return;
    _beschaeftigt = true;
    try {
      final ExportDatei? datei;
      try {
        datei = await ref.read(exportDateiWaehlerProvider).waehle();
      } on Object catch (fehler) {
        state = UebernahmeGescheitert(fehler);
        return;
      }
      if (datei == null) return;

      state = const UebernahmeLaeuft();
      final TrainingsexportErgebnis ergebnis;
      try {
        ergebnis = await uebernimmTrainingsexport(
          ref.read(gymRepositoryProvider),
          datei.bytes,
          // Die eine Stelle, an der die Umfänge-Ablage mitgegeben wird.
          // Ohne sie liefe der Lauf durch und schriebe keinen Umfang.
          umfaenge: ref.read(umfaengeRepositoryProvider),
        );
      } on Object catch (fehler) {
        state = UebernahmeGescheitert(fehler);
        return;
      }

      switch (ergebnis) {
        case TrainingsexportAbgelehnt(:final grund):
          state = UebernahmeAbgelehnt(grund);
        case TrainingsexportUebernommen():
          state = UebernahmeFertig(ergebnis);
          // Alle Gym-Provider hängen an den Sitzungen. Ohne das zeigte der
          // Verlauf „noch nichts da", obwohl die Übernahme „neu" gemeldet
          // hat, und die Gym-Übersicht plante nach dem alten Stand.
          ref.invalidate(gymSitzungenProvider);
          // Dasselbe für die Umfänge: Ohne das zeigte die Übersicht „noch
          // nichts gemessen", während der Bericht Werte meldet — Fehler
          // `01` in neuer Verkleidung. Die Kachel auf `koerper` und die
          // ganze Familie des Formulars hängen ebenso am Stand; der Vorwert
          // eines späteren Tages ändert sich mit.
          ref.invalidate(umfaengeMessungenProvider);
          ref.invalidate(umfaengeLetzterMesstagProvider);
          ref.invalidate(umfangsFormularLaufProvider);
      }
    } finally {
      _beschaeftigt = false;
    }
  }
}

final uebernahmeProvider =
    NotifierProvider<UebernahmeNotifier, UebernahmeStand>(
      UebernahmeNotifier.new,
    );
