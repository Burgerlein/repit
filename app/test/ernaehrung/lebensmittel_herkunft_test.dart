// `drift` exportiert eigene `isNull` und `isNotNull` — dieselbe Begründung
// wie in `lebensmittel_repository_test.dart`, Zeile 1–5.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/data/lebensmittel_repository.dart';
import 'package:repit/ernaehrung/erfassen_formular.dart';
import 'package:repit/ernaehrung/erfassen_provider.dart';
import 'package:repit/health/health_provider.dart';

/// Tests für die **Übernahme** eines Open-Food-Facts-Produkts in die
/// eigene Tabelle (#284): Herkunft und Strichcode an der Vorlage, und dass
/// ein zweites Buchen kein zweites Lebensmittel anlegt.
///
/// Der Client selbst steht in `off_client_test.dart`, die Oberfläche in
/// `off_suche_view_test.dart`, die Migration in
/// `test/data/schema_v14_test.dart`. **Diese Datei importiert `http`
/// nicht** — sie wird rot an dem, was ihr fehlt, nicht am Paket.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, aber nicht verändert
/// werden.
///
/// ## Was diese Tests verbindlich vorgeben
///
/// Neu in `lib/data/lebensmittel_repository.dart`:
///
/// ```dart
/// /// Woher eine Vorlage stammt. In der Datenbank als Text: `'eigen'`,
/// /// `'off'`.
/// enum Herkunft { eigen, off }
///
/// class LebensmittelVorlage {
///   const LebensmittelVorlage({
///     … wie bisher …,
///     this.barcode,                  // null bei selbst angelegten
///     this.herkunft = Herkunft.eigen,
///   });
///   final String? barcode;
///   final Herkunft herkunft;
///   // == und hashCode schließen beide ein
/// }
///
/// class LebensmittelRepository {
///   … wie bisher …
///
///   /// Die Vorlage zu einem Strichcode — `null`, wenn keine da ist.
///   Future<LebensmittelVorlage?> zuBarcode(String barcode);
///
///   /// Übernimmt ein Produkt aus Open Food Facts und gibt den Schlüssel
///   /// zurück. **Liegt der Strichcode schon in der Tabelle, wird nichts
///   /// angelegt und nichts überschrieben** — es gilt die vorhandene
///   /// Zeile. Wirft `ArgumentError`, wenn `vorlage.barcode` null ist.
///   Future<int> uebernimm(LebensmittelVorlage vorlage);
/// }
/// ```
///
/// `legeAn`, `lies`, `suche` und `aendere` tragen `barcode` und
/// `herkunft` mit. `ErfassenNotifier.buche` übernimmt eine Vorlage ohne
/// Schlüssel mit Herkunft `off` **beim Buchen** in die eigene Tabelle und
/// bucht auf die übernommene Zeile.
///
/// Dafür bekommt `lebensmittel` die Spalten `barcode` und `herkunft`
/// (Schema v14, siehe `test/data/schema_v14_test.dart`).
///
/// ## Entscheidung des Test-Agenten: die eigene Kopie gewinnt
///
/// **Nicht mit Tim abgestimmt, nicht freigegeben** — mit Begründung. Wird
/// ein Produkt übernommen, dessen Strichcode schon in der Tabelle liegt,
/// bleiben **deren** Werte stehen, auch wenn Open Food Facts inzwischen
/// andere liefert. „Die eigene Tabelle ist die Wahrheit" (Spec, Punkt 1):
/// Tim kann die Kopie korrigiert haben, und ein stilles Überschreiben beim
/// nächsten Buchen nähme ihm die Korrektur weg.
///
/// ## Entscheidung des Test-Agenten: übernommen wird erst beim Buchen
///
/// **Nicht mit Tim abgestimmt, nicht freigegeben** — wörtlich aus Brief
/// und Spec („Ergebnisse in die eigene Tabelle übernommen, **sobald eines
/// gebucht wird**"). Ein angetipptes und wieder verworfenes Produkt landet
/// nicht in der Tabelle; sonst füllte sich die eigene Suche mit allem, was
/// Tim je angesehen und nicht gegessen hat. Hier geprüft am Schreibweg,
/// in `off_suche_view_test.dart` am Abbrechen.
///
/// Alle Produkte, Namen und Strichcodes hier sind **erfunden**.
void main() {
  // Dienstag, 14.07.2026, 12:00 Berliner Zeit (MESZ, +2).
  final jetzt = DateTime.utc(2026, 7, 14, 10);
  const heute = '2026-07-14';

  const barcodeHafer = '0000000000017';
  const barcodeSkyr = '0000000000024';

  /// Mit Lücken: Zucker, gesättigte Fettsäuren und Ballaststoffe fehlen.
  /// Die Lücken müssen die Übernahme überstehen.
  const haferJe100g = Naehrwerte.je100g(
    kcal: 371,
    eiweissG: 12.5,
    kohlenhydrateG: 59,
    fettG: 6.5,
  );

  /// Ein gefundenes Produkt, wie `OffProdukt.alsVorlage()` es liefert:
  /// ohne Schlüssel, Herkunft `off`, mit Strichcode. Von Hand gebaut,
  /// damit diese Datei `off_client.dart` und damit `http` nicht braucht.
  LebensmittelVorlage gefunden({
    String barcode = barcodeHafer,
    String name = 'Haferflocken Prüfmühle',
    Naehrwerte je100g = haferJe100g,
  }) => LebensmittelVorlage(
    name: name,
    je100g: je100g,
    barcode: barcode,
    herkunft: Herkunft.off,
  );

  ({ProviderContainer container, AppCache db, LebensmittelRepository repo})
  behaelter() {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);

    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
      ],
    );
    addTearDown(container.dispose);
    return (
      container: container,
      db: db,
      repo: container.read(lebensmittelRepositoryProvider),
    );
  }

  /// Wie viele Zeilen in `lebensmittel` stehen — gefragt wird die Datei,
  /// nicht der erzeugte Zugriff.
  Future<int> anzahlLebensmittel(AppCache db) async {
    final zeile = await db
        .customSelect('SELECT COUNT(*) AS anzahl FROM lebensmittel;')
        .getSingle();
    return zeile.read<int>('anzahl');
  }

  /// `barcode` und `herkunft` einer Zeile, roh aus der Datei.
  Future<({String? barcode, String herkunft})> rohHerkunft(
    AppCache db,
    int id,
  ) async {
    final zeile = await db
        .customSelect(
          'SELECT barcode, herkunft FROM lebensmittel WHERE id = ?;',
          variables: [Variable<int>(id)],
        )
        .getSingle();
    return (
      barcode: zeile.read<String?>('barcode'),
      herkunft: zeile.read<String>('herkunft'),
    );
  }

  Future<void> bucheGefunden(
    ProviderContainer container,
    LebensmittelVorlage vorlage, {
    String menge = '50',
  }) {
    final formular = BuchungsFormular.neu(
      vorlage: vorlage,
      tagesSchluessel: heute,
      jetzt: jetzt,
    ).mitMenge(menge);
    return container.read(erfassenProvider.notifier).buche(formular);
  }

  Future<List<Eintrag>> eintraegeHeute(AppCache db) =>
      ErnaehrungRepository(db).eintraegeAmTag(heute);

  // ═════════════════════════════════════════════════════════════════════
  group('Die Vorlage kennt ihre Herkunft', () {
    test('ohne Angabe ist sie eigen und ohne Strichcode', () {
      const v = LebensmittelVorlage(name: 'Prüfbrot', je100g: haferJe100g);

      expect(v.herkunft, Herkunft.eigen);
      expect(v.barcode, isNull);
    });

    test('Strichcode und Herkunft gehören zur Gleichheit', () {
      final a = gefunden();
      final b = gefunden();
      final andererCode = gefunden(barcode: barcodeSkyr);
      const eigen = LebensmittelVorlage(
        name: 'Haferflocken Prüfmühle',
        je100g: haferJe100g,
        barcode: barcodeHafer,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(andererCode));
      expect(a, isNot(eigen), reason: 'gleich bis auf die Herkunft');
    });

    test('selbst Angelegtes steht als eigen ohne Strichcode in der Datei', () async {
      final b = behaelter();

      final id = await b.repo.legeAn(
        const LebensmittelVorlage(name: 'Prüfbrot', je100g: haferJe100g),
      );

      final roh = await rohHerkunft(b.db, id);
      expect(roh.herkunft, 'eigen');
      expect(roh.barcode, isNull);

      final gelesen = await b.repo.lies(id);
      expect(gelesen!.herkunft, Herkunft.eigen);
      expect(gelesen.barcode, isNull);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('uebernimm', () {
    test('legt das Produkt mit Strichcode und Herkunft off an', () async {
      final b = behaelter();

      final id = await b.repo.uebernimm(gefunden());

      final roh = await rohHerkunft(b.db, id);
      expect(roh.herkunft, 'off');
      expect(roh.barcode, barcodeHafer);

      final gelesen = (await b.repo.lies(id))!;
      expect(gelesen.id, id);
      expect(gelesen.name, 'Haferflocken Prüfmühle');
      expect(gelesen.herkunft, Herkunft.off);
      expect(gelesen.barcode, barcodeHafer);
      expect(gelesen.je100g, haferJe100g);
      expect(
        gelesen.je100g.zuckerG,
        isNull,
        reason: 'eine Lücke aus Open Food Facts bleibt eine Lücke, keine 0',
      );
      expect(
        gelesen.zuletztBenutzt,
        isNull,
        reason: 'übernommen ist nicht gebucht — das merkt sich `buche`',
      );
    });

    test('ein zweites Mal legt nichts an und gibt denselben Schlüssel', () async {
      final b = behaelter();

      final erst = await b.repo.uebernimm(gefunden());
      final dann = await b.repo.uebernimm(gefunden());

      expect(dann, erst);
      expect(await anzahlLebensmittel(b.db), 1);
    });

    test('die eigene Kopie gewinnt — neue OFF-Werte überschreiben nichts', () async {
      final b = behaelter();

      final id = await b.repo.uebernimm(gefunden());
      await b.repo.uebernimm(
        gefunden(
          name: 'Haferflocken Prüfmühle NEU',
          je100g: const Naehrwerte.je100g(kcal: 999),
        ),
      );

      final gelesen = (await b.repo.lies(id))!;
      expect(gelesen.name, 'Haferflocken Prüfmühle');
      expect(gelesen.je100g, haferJe100g);
    });

    test('verschiedene Strichcodes sind verschiedene Lebensmittel', () async {
      final b = behaelter();

      final hafer = await b.repo.uebernimm(gefunden());
      final skyr = await b.repo.uebernimm(
        gefunden(barcode: barcodeSkyr, name: 'Skyr Prüfhof'),
      );

      expect(skyr, isNot(hafer));
      expect(await anzahlLebensmittel(b.db), 2);
    });

    test('ohne Strichcode wirft es — das wäre ein Programmierfehler', () async {
      final b = behaelter();

      await expectLater(
        b.repo.uebernimm(
          const LebensmittelVorlage(
            name: 'Ohne Code',
            je100g: haferJe100g,
            herkunft: Herkunft.off,
          ),
        ),
        throwsArgumentError,
      );
      expect(await anzahlLebensmittel(b.db), 0);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('zuBarcode', () {
    test('findet die Vorlage zum Strichcode', () async {
      final b = behaelter();
      final id = await b.repo.uebernimm(gefunden());

      final v = await b.repo.zuBarcode(barcodeHafer);

      expect(v, isNotNull);
      expect(v!.id, id);
      expect(v.herkunft, Herkunft.off);
    });

    test('ein unbekannter Strichcode ist null, kein leerer Datensatz', () async {
      final b = behaelter();
      await b.repo.uebernimm(gefunden());

      expect(await b.repo.zuBarcode(barcodeSkyr), isNull);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Die eigene Suche trägt die Herkunft mit', () {
    test('ein übernommenes Produkt erscheint mit Strichcode und Herkunft off', () async {
      final b = behaelter();
      await b.repo.legeAn(
        const LebensmittelVorlage(name: 'Haferbrot eigen', je100g: haferJe100g),
      );
      await b.repo.uebernimm(gefunden());

      final treffer = await b.repo.suche('Hafer');

      final off = treffer.singleWhere((v) => v.barcode == barcodeHafer);
      expect(off.herkunft, Herkunft.off);
      final eigen = treffer.singleWhere((v) => v.name == 'Haferbrot eigen');
      expect(eigen.herkunft, Herkunft.eigen);
      expect(eigen.barcode, isNull);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Buchen übernimmt in die eigene Tabelle', () {
    test('ein gefundenes Produkt wird beim Buchen angelegt und gebucht', () async {
      final b = behaelter();
      expect(await anzahlLebensmittel(b.db), 0);

      await bucheGefunden(b.container, gefunden());

      expect(await anzahlLebensmittel(b.db), 1);
      final vorlage = await b.repo.zuBarcode(barcodeHafer);
      expect(vorlage, isNotNull, reason: 'ab jetzt offline da');
      expect(vorlage!.herkunft, Herkunft.off);

      final eintraege = await eintraegeHeute(b.db);
      expect(eintraege, hasLength(1));
      expect(
        eintraege.single.lebensmittelId,
        vorlage.id,
        reason:
            'der Eintrag zeigt auf die übernommene Zeile — sonst stünde er '
            'wie ein Schnelleintrag ohne Vorlage da',
      );
      expect(eintraege.single.name, 'Haferflocken Prüfmühle');
      expect(eintraege.single.mengeG, 50);
      expect(eintraege.single.naehrwerte.kcal, closeTo(185.5, 1e-9));
      expect(
        eintraege.single.naehrwerte.zuckerG,
        isNull,
        reason: 'die Lücke wandert mit, sie wird nicht zu 0',
      );
    });

    test('Buchen merkt sich die Benutzung — es steht danach in „zuletzt '
        'benutzt"', () async {
      final b = behaelter();

      await bucheGefunden(b.container, gefunden());

      final vorlage = (await b.repo.zuBarcode(barcodeHafer))!;
      expect(vorlage.zuletztBenutzt, jetzt);

      final zuletzt = await b.repo.suche('');
      expect(zuletzt.first.barcode, barcodeHafer);
    });

    test('ein zweites Buchen desselben Produkts legt kein zweites an', () async {
      final b = behaelter();

      // Zweimal aus einem frischen Fund — so, als hätte die Suche das
      // Produkt beide Male aus Open Food Facts gezeigt.
      await bucheGefunden(b.container, gefunden(), menge: '50');
      await bucheGefunden(b.container, gefunden(), menge: '80');

      expect(await anzahlLebensmittel(b.db), 1);
      final eintraege = await eintraegeHeute(b.db);
      expect(eintraege, hasLength(2));
      expect(
        eintraege.map((e) => e.lebensmittelId).toSet(),
        hasLength(1),
        reason: 'beide Einträge zeigen auf dieselbe Vorlage',
      );
    });

    test('nach dem Buchen findet die eigene Suche es — ohne Neustart', () async {
      final b = behaelter();
      final abo = b.container.listen(suchtrefferProvider, (_, _) {});
      addTearDown(abo.close);
      b.container.read(suchtextProvider.notifier).setze('Hafer');
      expect(await b.container.read(suchtrefferProvider.future), isEmpty);

      await bucheGefunden(b.container, gefunden());

      final treffer = await b.container.read(suchtrefferProvider.future);
      expect(treffer.map((v) => v.barcode), [barcodeHafer]);
    });

    test('ein eigenes Lebensmittel bucht wie bisher, ohne Übernahme', () async {
      final b = behaelter();
      final id = await b.repo.legeAn(
        const LebensmittelVorlage(name: 'Prüfbrot', je100g: haferJe100g),
      );

      await bucheGefunden(b.container, (await b.repo.lies(id))!);

      expect(await anzahlLebensmittel(b.db), 1);
      expect((await eintraegeHeute(b.db)).single.lebensmittelId, id);
    });
  });
}
