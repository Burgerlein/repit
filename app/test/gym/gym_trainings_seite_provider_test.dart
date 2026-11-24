import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/muskel_figur.dart' show MuskelSeite;
import 'package:repit/gym/gym_trainings_provider.dart';

/// Tests für **`gymTrainingsSeiteProvider`** — die gewählte Seite der
/// Muskelfigur je Training (#532/#533, unter #531; Spec 6.3 und 7.5).
/// Task 1.8 des Plans `docs/superpowers/plans/2026-11-19-eigene-trainings-
/// plan.md`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// ## Warum eine eigene Datei
///
/// **Der Plan stellt `gymTrainingsSeiteProvider` in Task 1.9 (Scheibe 1),
/// den Typ `MuskelSeite` aber in Task 2.1 (Scheibe 2,
/// `app/lib/design/muskel_figur.dart`).** Wer 1.9 vor 2.1 baut, hat keinen
/// Typ, den der Provider halten könnte. Damit dieser Widerspruch nicht die
/// übrigen Provider-Tests in `gym_trainings_provider_test.dart` blockiert
/// (die kein `MuskelSeite` brauchen), steht dieser Teil allein. **Gemeldet,
/// nicht entschieden:** entweder 2.1 (nur der Enum `MuskelSeite`) wandert
/// vor 1.9, oder der Provider folgt mit 2.1.
///
/// ## Wer hat was entschieden
///
/// - **Entscheidung von Tim [19.11.2026, Spec 22 Nr. 2 und 7.5]:** Gedreht
///   wird nur die Kachel-Figur; sie **startet immer „vorne"**; die gewählte
///   Seite wird nur im Schirm gehalten.
/// - **Vorschlag der Spec, hier vorausgesetzt:** 17.10 — **nicht**
///   persistiert über den App-Start, **überlebt Navigation** (Fehler `32`).
/// - **Folgerung aus Spec 6.3:** „hält je Training-ID die gewählte Seite
///   (`MuskelSeite.vorne`/`hinten`; ohne Eintrag `vorne`)".
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// Spec 6.3 sagt „hält je Training-ID" und legt nicht fest, ob als Familie
/// oder als Karte. **Festlegung des Test-Agenten — Tim hat sie nicht
/// gesehen:**
///
/// ```dart
/// enum MuskelSeite { vorne, hinten }                // Task 2.1
/// final gymTrainingsSeiteProvider =
///     NotifierProvider.family<…, MuskelSeite, String>(…);   // je Training-ID
///     // Notifier: `void setze(MuskelSeite seite)`
/// ```
///
/// ## Was hier **nicht** getestet wird
///
/// - **Das Drehen selbst** (Swipe, Animation) — Widget-Tests der Übersicht.
/// - **Das Ende der Lebensdauer beim App-Start** — „nicht persistiert" lässt
///   sich in einem Container-Test nur so zeigen: ein neuer Container beginnt
///   wieder bei „vorne" (letzter Fall unten).
void main() {
  ProviderContainer huelle() {
    final container = ProviderContainer(retry: (_, _) => null);
    addTearDown(container.dispose);
    return container;
  }

  test('ohne Eintrag ist die Seite „vorne"', () {
    final container = huelle();

    expect(container.read(gymTrainingsSeiteProvider('Push')), MuskelSeite.vorne);
    expect(container.read(gymTrainingsSeiteProvider('E-1')), MuskelSeite.vorne);
  });

  test('die gewählte Seite wird je Training gehalten, die anderen bleiben '
      '„vorne"', () {
    final container = huelle();

    container
        .read(gymTrainingsSeiteProvider('Push').notifier)
        .setze(MuskelSeite.hinten);

    expect(container.read(gymTrainingsSeiteProvider('Push')), MuskelSeite.hinten);
    expect(container.read(gymTrainingsSeiteProvider('Pull')), MuskelSeite.vorne);
    expect(container.read(gymTrainingsSeiteProvider('E-1')), MuskelSeite.vorne);
  });

  test('zurückdrehen geht', () {
    final container = huelle();
    final notifier = container.read(gymTrainingsSeiteProvider('Push').notifier)
      ..setze(MuskelSeite.hinten);

    notifier.setze(MuskelSeite.vorne);

    expect(container.read(gymTrainingsSeiteProvider('Push')), MuskelSeite.vorne);
  });

  test('die Seite überlebt das Verlassen der Ansicht (Fehler `32`)', () {
    final container = huelle();
    final abo = container.listen(
      gymTrainingsSeiteProvider('Legs'),
      (_, _) {},
    );
    container
        .read(gymTrainingsSeiteProvider('Legs').notifier)
        .setze(MuskelSeite.hinten);

    abo.close(); // die Kachel verlässt den Baum

    expect(container.read(gymTrainingsSeiteProvider('Legs')), MuskelSeite.hinten);
  });

  test('wer die Seite hält, benachrichtigt nur bei einer Änderung', () {
    final container = huelle();
    var benachrichtigt = 0;
    final abo = container.listen(
      gymTrainingsSeiteProvider('Push'),
      (_, _) => benachrichtigt++,
    );
    addTearDown(abo.close);
    final notifier = container.read(gymTrainingsSeiteProvider('Push').notifier);

    notifier.setze(MuskelSeite.vorne); // schon vorne
    expect(benachrichtigt, 0);
    notifier.setze(MuskelSeite.hinten);
    expect(benachrichtigt, 1);
    notifier.setze(MuskelSeite.hinten);
    expect(benachrichtigt, 1);
  });

  test('nicht persistiert: ein neuer Container beginnt wieder bei „vorne"',
      () {
    final erster = huelle();
    erster
        .read(gymTrainingsSeiteProvider('Push').notifier)
        .setze(MuskelSeite.hinten);

    final zweiter = huelle(); // ein App-Start

    expect(zweiter.read(gymTrainingsSeiteProvider('Push')), MuskelSeite.vorne);
  });
}
