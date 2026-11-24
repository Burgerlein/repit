import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:trainings_core/trainings_core.dart';
import 'package:repit/data/lebensmittel_repository.dart';
import 'package:repit/ernaehrung/erfassen_provider.dart';
import 'package:repit/ernaehrung/seed_datenbank.dart';
import 'package:repit/ernaehrung/seed_suche_provider.dart';

/// Tests für die **zweite Suchstufe**: die mitgelieferte Seed-Datenbank
/// zwischen den eigenen Lebensmitteln und Open Food Facts (#543).
///
/// Maßstab ist `docs/superpowers/specs/2026-11-03-ernaehrung-design.md`,
/// Abschnitt „Die Suche läuft lokal zuerst (geändert 18.11.2026, #542)":
/// Gesucht wird in drei Stufen — **(1) eigene**, **(2) Seed**, **(3) OFF
/// online** —, und ein Treffer, den man schon selbst hat, erscheint nicht
/// zweimal.
///
/// **Die Rangfolge innerhalb des Seeds steht hier nicht zur Prüfung.** Sie
/// liegt in `SeedDatenbank.suche` und ist in `seed_datenbank_test.dart`
/// gegen die echte Asset-Datei festgenagelt („hartgekochtes Ei" →
/// „Hühnerei gekocht"). Diese Datei prüft die Stufe *darüber*: wann
/// gefragt wird, was weggelassen wird, und dass nicht bei jedem Zugriff
/// neu gefragt wird (Hausregel 2 — genau der Fehler `03`).
///
/// **Warum in den Entdopplungsfällen `await` steht:**
/// [suchtrefferProvider] ist ein `AsyncNotifierProvider`; sein Wert liegt
/// erst nach einem Microtask vor, synchron gelesen ist er `null`. Ohne das
/// `await` prüfte der Fall also eine erste Stufe, die noch gar nichts
/// geliefert hat — und wäre selbst dann grün, wenn gar nicht entdoppelt
/// würde. Nachgetragen am 23.11.2026, nachdem genau das aufgefallen war
/// (gemessen, nicht vermutet: synchron `null`, nach `await …future` der
/// Wert). In der App liegt die erste Stufe vor, während jemand tippt.
///
/// Alle Namen und Zahlen sind erfunden.
void main() {
  /// Ein Doppelgänger, der **zählt**, wie oft gefragt wurde, und eine
  /// feste Antwort gibt — die echte Datenbank ist hier nicht der
  /// Prüfgegenstand.
  late _ZaehlendeSeed seed;

  /// Was die erste Stufe (eigene Lebensmittel) liefert.
  late List<LebensmittelVorlage> eigene;

  SeedTreffer treffer(
    String name, {
    String quelle = 'bls',
    String schluessel = 'B-1',
  }) => SeedTreffer(
    quelle: quelle,
    schluessel: schluessel,
    name: name,
    je100g: const Naehrwerte(kcal: 111),
    fluessig: false,
  );

  LebensmittelVorlage eigenes(
    String name, {
    String? barcode,
    String? quelleSchluessel,
  }) => LebensmittelVorlage(
    name: name,
    je100g: const Naehrwerte(kcal: 111),
    barcode: barcode,
    quelleSchluessel: quelleSchluessel,
  );

  ProviderContainer behaelter() {
    final c = ProviderContainer(
      // Ohne das hängt ein erzwungener Fehler in einem
      // nichtdeterministischen Zwischenzustand (`CLAUDE.md`, Tests).
      retry: (_, _) => null,
      overrides: [
        seedDatenbankProvider.overrideWithValue(seed),
        suchtrefferProvider.overrideWith(() => _FesteTreffer(eigene)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    seed = _ZaehlendeSeed();
    eigene = const [];
  });

  group('Wann überhaupt gefragt wird', () {
    test('unter zwei Zeichen wird nicht gefragt und nichts geliefert', () {
      seed.antwort = [treffer('Toastbrot glutenfrei')];
      final c = behaelter();

      c.read(suchtextProvider.notifier).setze('t');

      expect(c.read(seedSucheProvider), isEmpty);
      expect(
        seed.anfragen,
        0,
        reason:
            'ein einzelner Buchstabe trifft tausende Zeilen — gefragt wird '
            'erst, wenn die Eingabe etwas eingrenzt',
      );
    });

    test('leerer Suchtext liefert nichts — das ist „zuletzt benutzt", '
        'nicht der Seed', () {
      final c = behaelter();

      expect(c.read(seedSucheProvider), isEmpty);
      expect(seed.anfragen, 0);
    });

    test('ab zwei Zeichen kommen die Treffer des Seeds', () {
      seed.antwort = [treffer('Toastbrot glutenfrei'), treffer('Toastbrot')];
      final c = behaelter();

      c.read(suchtextProvider.notifier).setze('to');

      expect(
        c.read(seedSucheProvider).map((t) => t.name),
        ['Toastbrot glutenfrei', 'Toastbrot'],
        reason:
            'die Reihenfolge kommt aus SeedDatenbank.suche und wird hier '
            'nicht angetastet',
      );
      expect(seed.anfragen, 1);
      expect(seed.zuletztGefragt, 'to');
    });
  });

  group('Was man schon selbst hat, erscheint nicht zweimal', () {
    test('ein Seed-Treffer mit bekanntem Quellschlüssel fällt weg', () async {
      eigene = [eigenes('Hühnerei gekocht', quelleSchluessel: 'B-7')];
      seed.antwort = [
        treffer('Hühnerei gekocht', schluessel: 'B-7'),
        treffer('Hühnerei roh', schluessel: 'B-8'),
      ];
      final c = behaelter();

      c.read(suchtextProvider.notifier).setze('ei');
      await c.read(suchtrefferProvider.future);

      expect(
        c.read(seedSucheProvider).map((t) => t.schluessel),
        ['B-8'],
        reason:
            'die eigene Zeile steht in Stufe 1 und ist dieselbe Sache — '
            'zweimal dasselbe Lebensmittel ist kein Treffer mehr, sondern '
            'eine Verwechslungsgefahr beim Buchen',
      );
    });

    test('ein Seed-Produkt aus Open Food Facts fällt weg, wenn sein '
        'Strichcode schon als eigener dasteht', () async {
      eigene = [eigenes('Nussnugatcreme', barcode: '4000539000000')];
      seed.antwort = [
        treffer(
          'Nussnugatcreme',
          quelle: 'off',
          schluessel: '4000539000000',
        ),
        treffer('Nussnugatcreme leicht', quelle: 'off', schluessel: '4000539000001'),
      ];
      final c = behaelter();

      c.read(suchtextProvider.notifier).setze('nuss');
      await c.read(suchtrefferProvider.future);

      expect(
        c.read(seedSucheProvider).map((t) => t.schluessel),
        ['4000539000001'],
        reason:
            'bei OFF-Zeilen ist der Quellschlüssel die EAN — abgeglichen '
            'wird gegen den Strichcode der eigenen Zeile',
      );
    });

    test('gleiche Namen allein reichen nicht zum Weglassen', () async {
      eigene = [eigenes('Haferflocken')];
      seed.antwort = [treffer('Haferflocken', schluessel: 'B-3')];
      final c = behaelter();

      c.read(suchtextProvider.notifier).setze('hafer');
      await c.read(suchtrefferProvider.future);

      expect(
        c.read(seedSucheProvider), hasLength(1),
        reason:
            'ohne gemeinsamen Schlüssel ist nicht entscheidbar, ob es '
            'dasselbe Lebensmittel ist — zwei Zeilen „Haferflocken" können '
            'zwei verschiedene Sorten sein. Weglassen würde hier einen '
            'echten Treffer verschlucken',
      );
    });
  });

  group('Der Seed hängt nicht am Netz', () {
    test('die Treffer stehen auch dann da, wenn nur die eigene Stufe '
        'Daten hat und nichts online erreichbar ist', () {
      // Der Online-Zustand wird hier gar nicht erst gesetzt: Dieser
      // Provider liest ihn nicht und darf ihn nicht lesen. Genau das ist
      // die Zusage der Spec — Stufe 1 und 2 bleiben ohne Netz vollständig.
      seed.antwort = [treffer('Banane roh')];
      final c = behaelter();

      c.read(suchtextProvider.notifier).setze('banane');

      expect(c.read(seedSucheProvider), hasLength(1));
    });
  });

  group('Gehalten, nicht je Zugriff gerechnet', () {
    test('mehrmaliges Lesen bei gleichem Suchtext fragt die Datenbank '
        'genau einmal', () {
      seed.antwort = [treffer('Magerquark')];
      final c = behaelter();

      c.read(suchtextProvider.notifier).setze('quark');
      c.read(seedSucheProvider);
      c.read(seedSucheProvider);
      c.read(seedSucheProvider);

      expect(
        seed.anfragen,
        1,
        reason:
            'ein abgeleiteter Provider rechnet neu, wenn sich seine '
            'Abhängigkeit ändert — nicht je Zugriff. Je Bild zu fragen '
            'wäre `03`, wortgleich, im neuen Code',
      );
    });

    test('ein neuer Suchtext fragt erneut', () {
      seed.antwort = [treffer('Magerquark')];
      final c = behaelter();

      c.read(suchtextProvider.notifier).setze('quark');
      c.read(seedSucheProvider);
      c.read(suchtextProvider.notifier).setze('skyr');
      c.read(seedSucheProvider);

      expect(seed.anfragen, 2);
      expect(seed.zuletztGefragt, 'skyr');
    });
  });
}

/// Zählt die Anfragen und antwortet fest — ohne Datei, ohne SQL.
class _ZaehlendeSeed extends SeedDatenbank {
  _ZaehlendeSeed() : super.leer();

  List<SeedTreffer> antwort = const [];
  int anfragen = 0;
  String? zuletztGefragt;

  @override
  List<SeedTreffer> suche(String text, {int grenze = 25}) {
    anfragen++;
    zuletztGefragt = text;
    return antwort;
  }
}

/// Die erste Stufe als fester Wert — `LebensmittelRepository` und seine
/// Datenbank stehen hier nicht zur Prüfung.
class _FesteTreffer extends SuchtrefferNotifier {
  _FesteTreffer(this._werte);

  final List<LebensmittelVorlage> _werte;

  @override
  Future<List<LebensmittelVorlage>> build() async => _werte;
}
