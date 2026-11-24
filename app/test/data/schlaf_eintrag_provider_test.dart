import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/schlaf_eintrag.dart';
import 'package:repit/health/health_provider.dart';

/// Tests für die **Provider-Schicht** über den eigenen Schlafeinträgen
/// (#131, Zug 1) — `schlafEintraegeProvider` in
/// `lib/data/schlaf_eintrag.dart`. Die Ablage darunter prüft
/// `schlaf_eintrag_test.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Entscheidungen dieser Testdatei
///
/// - **Kein `Messwert<T>`.** Zweite Tabellengruppe (Spec 5.6a): Hinter
///   diesen Zeilen steht kein Lauf, der leer ausgehen könnte, sondern Tim.
///   Der Zustand ist deshalb schlicht `List<SchlafEintrag>` — leer heißt
///   leer. Das ist derselbe Schnitt wie bei `zieleProvider`.
/// - **Ein Provider für Nacht und Tagschlaf gemeinsam.** Beide Schirme
///   brauchen dieselbe Lesung über dasselbe Fenster; zwei Provider wären
///   zwei Datenbankabfragen für eine Tabelle. Welche Zeilen ein Schirm
///   zeigt, entscheidet er selbst über `art`.
/// - **Das Fenster ist `rechenfensterProvider`** — dasselbe wie bei
///   `sleepProvider`. Eine eingetragene Nacht, die außerhalb des Fensters
///   läge, über das der Schlaf-Schirm rechnet, wäre eine Zeile, die es gibt
///   und die niemand sieht.
/// - **Schreiben geht durch den Notifier, nicht am ihm vorbei.** Wer das
///   Repository direkt beschriebe, hinterließe einen Zustand, der nicht
///   mehr stimmt — genau der Fehler, gegen den `#118` geschrieben ist
///   („fünf Gesichter, die beim Zurückkommen vergessen sind").
void main() {
  ProviderContainer behaelter(AppCache db, {DateTime? jetzt}) {
    final container = ProviderContainer(
      // Riverpods Wiederholung in Tests aus (`CLAUDE.md`): Sonst hängt ein
      // erzwungener Fehler in einem nichtdeterministischen Zwischenzustand.
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        if (jetzt != null) clockProvider.overrideWithValue(() => jetzt),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('ohne einen einzigen Eintrag ist die Liste leer, nicht null', () async {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    final container = behaelter(db);

    expect(await container.read(schlafEintraegeProvider.future), isEmpty);
  });

  test('eingetragen heißt sofort gelesen — ohne zweiten Umweg', () async {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    // Ein Zeitpunkt mitten im Rechenfenster, damit der eingetragene Tag
    // sicher darin liegt.
    final container = behaelter(db, jetzt: DateTime.utc(2026, 10, 29, 9));

    await container.read(schlafEintraegeProvider.future);
    await container
        .read(schlafEintraegeProvider.notifier)
        .setzeNacht(
          tag: '2026-10-29',
          schlafMinuten: 425,
          beginnMinuten: 23 * 60 + 10,
          endeMinuten: 6 * 60 + 15,
        );

    final eintraege = await container.read(schlafEintraegeProvider.future);
    expect(eintraege, hasLength(1));
    expect(eintraege.single.schlafMinuten, 425);
    expect(eintraege.single.art, SchlafEintragArt.nacht);
  });

  test('ein Nickerchen landet daneben, nicht statt der Nacht', () async {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    final container = behaelter(db, jetzt: DateTime.utc(2026, 10, 29, 9));

    await container.read(schlafEintraegeProvider.future);
    final notifier = container.read(schlafEintraegeProvider.notifier);
    await notifier.setzeNacht(tag: '2026-10-29', schlafMinuten: 420);
    await notifier.fuegeTagschlafHinzu(tag: '2026-10-29', schlafMinuten: 35);

    final eintraege = await container.read(schlafEintraegeProvider.future);
    expect(eintraege, hasLength(2));
    expect(eintraege.map((e) => e.art).toSet(), {
      SchlafEintragArt.nacht,
      SchlafEintragArt.tagschlaf,
    });
  });

  test('und Gelöschtes ist danach weg', () async {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    final container = behaelter(db, jetzt: DateTime.utc(2026, 10, 29, 9));

    await container.read(schlafEintraegeProvider.future);
    final notifier = container.read(schlafEintraegeProvider.notifier);
    await notifier.setzeNacht(tag: '2026-10-29', schlafMinuten: 420);
    await notifier.loescheNacht('2026-10-29');

    expect(await container.read(schlafEintraegeProvider.future), isEmpty);
  });

  test('gelesen wird über das Rechenfenster — ein Eintrag davor taucht nicht '
      'auf, obwohl er in der Tabelle steht', () async {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    // 30 Tage einschließlich heute: Der 01.09.2026 liegt sicher davor.
    final repo = SchlafEintragRepository(db);
    await repo.schreibeNacht(tag: '2026-09-01', schlafMinuten: 400);
    await repo.schreibeNacht(tag: '2026-10-29', schlafMinuten: 420);

    final container = behaelter(db, jetzt: DateTime.utc(2026, 10, 29, 9));

    final eintraege = await container.read(schlafEintraegeProvider.future);
    expect(eintraege.map((e) => e.tag), ['2026-10-29']);
  });

  test('ein unmöglicher Wert kommt als Fehler zurück und hinterlässt keine '
      'halbe Zeile', () async {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    final container = behaelter(db, jetzt: DateTime.utc(2026, 10, 29, 9));

    await container.read(schlafEintraegeProvider.future);
    await expectLater(
      container
          .read(schlafEintraegeProvider.notifier)
          .setzeNacht(tag: '2026-10-29', schlafMinuten: 0),
      throwsArgumentError,
    );

    expect(
      await SchlafEintragRepository(db).lies(DataWindow.unlimited),
      isEmpty,
    );
  });
}
