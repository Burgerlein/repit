import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';

/// Tests für die **Verdrahtung** des Ernährungs-Tag-Schirms (#282, Task 4)
/// — `lib/ernaehrung/ernaehrung_provider.dart` im Riverpod-Baum.
///
/// Die Rechnung darunter prüft `ernaehrung_tag_test.dart`, die Oberfläche
/// `ernaehrung_view_test.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, aber nicht verändert
/// werden.
///
/// ## Was diese Datei verbindlich vorgibt
///
/// ```dart
/// /// Der Tag, den der Schirm gerade zeigt — als ISO-Tagesstring.
/// final offenerTagProvider =
///     NotifierProvider<OffenerTagNotifier, String>(OffenerTagNotifier.new);
///
/// class OffenerTagNotifier extends Notifier<String> {
///   @override
///   String build();                     // der heutige Berliner Tag
///   void blaettere(int tage);           // ‹ ist -1, › ist +1
///   void setze(String tagesSchluessel);
/// }
///
/// /// Die eigenen Einträge eines Esstags. **Kein `Messwert`** — für Tims
/// /// eigene Daten gibt es keinen Lauf, der leer ausgehen kann.
/// final eigeneEintraegeProvider = AsyncNotifierProvider.family<
///     EigeneEintraegeNotifier, List<Eintrag>, String>(
///   EigeneEintraegeNotifier.new);
///
/// class EigeneEintraegeNotifier extends AsyncNotifier<List<Eintrag>> {
///   EigeneEintraegeNotifier(String tagesSchluessel);
///   final String tagesSchluessel;
///   @override
///   Future<List<Eintrag>> build();
///   Future<void> neuLesen();            // nach Buchen, Ändern, Löschen
/// }
///
/// /// Die fremden Mahlzeiten eines Esstags aus Apple Health.
/// final fremdeMahlzeitenProvider = AsyncNotifierProvider.family<
///     FremdeMahlzeitenNotifier, Messwert<List<FremdeMahlzeit>>, String>(
///   FremdeMahlzeitenNotifier.new);
///
/// class FremdeMahlzeitenNotifier
///     extends AsyncNotifier<Messwert<List<FremdeMahlzeit>>> {
///   FremdeMahlzeitenNotifier(String tagesSchluessel);
///   final String tagesSchluessel;
/// }
///
/// /// Der fertig gerechnete Tag.
/// final ernaehrungsTagProvider =
///     Provider.family<ErnaehrungsTag, String>((ref, tagesSchluessel) { … });
/// ```
///
/// ## Warum die Health-Hälfte hinter einem eigenen Provider liegt
///
/// `fremdeMahlzeitenProvider` ist die Naht zwischen diesem Schirm und dem
/// Kanal. Dahinter liegt Task 5: der Lesezugriff und der Quellenfilter,
/// der die **eigenen** Proben an ihrer Bundle-ID erkennt und überspringt
/// (Spec, Abschnitt „Quellen"). Was dort passiert, prüfen die Kanaltests;
/// **diese Datei fasst den Kanal nicht an.** Der Schirm bekommt fertige
/// `FremdeMahlzeit`-Werte, und nur deren Form steht hier fest. Zwei
/// Gründe:
///
/// - Die Rollentrennung: Der Kanal entsteht parallel in einem anderen
///   Zweig. Ein Test, der `NutritionEntry` festnagelte, nagelte eine Datei
///   fest, die dieser Auftrag gar nicht baut.
/// - Die Importrichtung: `FremdeMahlzeit` trägt `Naehrwerte` aus
///   `trainings_core` und nicht den Transporttyp des Kanals. Ein zweiter
///   Typ für dieselben acht Felder wäre eine zweite Stelle, an der `null`
///   zu `0` werden kann (#232).
///
/// ## Entscheidung des Test-Agenten: › geht nicht in die Zukunft
///
/// **Nicht mit Tim abgestimmt, nicht freigegeben** — mit Begründung. Der
/// Entwurf sagt zum Blättern nur „‹ ›  über Tage, wie auf den anderen
/// Schirmen". Ein Tag nach heute kann nichts zeigen als vier leere
/// Mahlzeiten und ein Ziel für einen Tag, der nicht stattgefunden hat; der
/// Schlaf-Schirm begrenzt sein Blättern aus demselben Grund
/// (`fruehesterSchlaftag`, #177). `setze` bleibt davon unberührt — wer
/// ausdrücklich einen Tag nennt, meint ihn.
///
/// Zahlen und Daten in dieser Datei sind erfunden.
void main() {
  // Dienstag, 14.07.2026, 12:00 Berliner Zeit (MESZ, +2).
  final jetzt = DateTime.utc(2026, 7, 14, 10);
  const heute = '2026-07-14';
  const gestern = '2026-07-13';

  const stammdaten = Stammdaten(
    groesseCm: 180,
    geburtsjahr: 1990,
    zielgewichtKg: 84,
    zieldatum: '2027-01-14',
  );

  DailyMetrics tageswert(String tag) => DailyMetrics(
    tag: tag,
    activeKcal: 600,
    basalKcal: 1600,
    weightKg: 80,
  );

  Eintrag eintrag({
    required String tag,
    Mahlzeit mahlzeit = Mahlzeit.mittag,
    int stundeUtc = 10,
    String name = 'Testgericht',
    double kcal = 400,
  }) => Eintrag(
    tagesSchluessel: tag,
    mahlzeit: mahlzeit,
    zeitpunkt: DateTime.utc(2026, 7, 14, stundeUtc),
    name: name,
    naehrwerte: Naehrwerte(kcal: kcal),
  );

  /// Ein Behälter mit echter Datenbank im Speicher und abgeschalteter
  /// Wiederholung (`CLAUDE.md`: sonst hängt ein erzwungener Fehler in
  /// einem nichtdeterministischen Zwischenzustand).
  ///
  /// Die Datenbank ist **echt**, nicht nachgebaut: `ErnaehrungRepository`
  /// filtert in SQL, und ein nachgebautes Repository prüfte genau das
  /// nicht mehr.
  ({ProviderContainer container, AppCache db}) behaelter({
    Messwert<List<FremdeMahlzeit>>? fremde,
    Messwert<List<DailyMetrics>>? tageswerte,
  }) {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);

    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        stammdatenProvider.overrideWith(() => _Stammdaten(stammdaten)),
        dailyMetricsProvider.overrideWith(
          () => _Tageswerte(
            tageswerte ??
                Bekannt<List<DailyMetrics>>([
                  tageswert(gestern),
                  tageswert(heute),
                ], stand: jetzt, laeuft: false),
          ),
        ),
        fremdeMahlzeitenProvider.overrideWith2(
          (tag) => _Fremde(
            fremde ??
                Bekannt<List<FremdeMahlzeit>>(
                  const [],
                  stand: jetzt,
                  laeuft: false,
                ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, db: db);
  }

  // ─────────────────────────────────────────────────────────────────────
  group('Der offene Tag', () {
    test('steht beim Start auf heute', () {
      final b = behaelter();
      expect(b.container.read(offenerTagProvider), heute);
    });

    test('‹ geht einen Tag zurück, › wieder vor', () {
      final b = behaelter();
      final notifier = b.container.read(offenerTagProvider.notifier);

      notifier.blaettere(-1);
      expect(b.container.read(offenerTagProvider), gestern);

      notifier.blaettere(1);
      expect(b.container.read(offenerTagProvider), heute);
    });

    test('› bleibt auf heute stehen — morgen gibt es nichts zu zeigen', () {
      final b = behaelter();
      b.container.read(offenerTagProvider.notifier).blaettere(1);
      expect(b.container.read(offenerTagProvider), heute);
    });

    test('setze nimmt jeden Tag, auch einen weit zurückliegenden', () {
      final b = behaelter();
      b.container.read(offenerTagProvider.notifier).setze('2026-03-29');
      expect(b.container.read(offenerTagProvider), '2026-03-29');
    });

    test('das Blättern läuft über den Kalender, nicht über 86400 Sekunden', () {
      // 29.03.2026 ist der Tag der Zeitumstellung: Er hat 23 Stunden.
      // Wer `+ 86400` rechnet, landet auf dem 29. statt auf dem 30.
      final b = behaelter();
      final notifier = b.container.read(offenerTagProvider.notifier);
      notifier.setze('2026-03-29');
      notifier.blaettere(1);
      expect(b.container.read(offenerTagProvider), '2026-03-30');
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Die eigenen Einträge', () {
    test('kommen aus der Datenbank und gehören dem richtigen Tag', () async {
      final b = behaelter();
      final repo = b.container.read(ernaehrungRepositoryProvider);
      await repo.buche(eintrag(tag: heute, name: 'Von heute'));
      await repo.buche(eintrag(tag: gestern, name: 'Von gestern'));

      final heutige = await b.container.read(
        eigeneEintraegeProvider(heute).future,
      );
      expect(heutige.map((e) => e.name), ['Von heute']);

      final gestrige = await b.container.read(
        eigeneEintraegeProvider(gestern).future,
      );
      expect(gestrige.map((e) => e.name), ['Von gestern']);
    });

    test('ein Tag ohne Eintrag ist leer, nicht null', () async {
      final b = behaelter();
      expect(
        await b.container.read(eigeneEintraegeProvider(heute).future),
        isEmpty,
      );
    });

    test('neuLesen holt nach, was inzwischen gebucht wurde', () async {
      // Der Weg, den das Buchungsblatt aus Task 7 nimmt: Es schreibt und
      // sagt dann Bescheid. Ohne ihn stünde der Eintrag erst nach einem
      // Neustart da.
      final b = behaelter();
      expect(
        await b.container.read(eigeneEintraegeProvider(heute).future),
        isEmpty,
      );

      await b.container
          .read(ernaehrungRepositoryProvider)
          .buche(eintrag(tag: heute, name: 'Nachgereicht'));
      await b.container.read(eigeneEintraegeProvider(heute).notifier).neuLesen();

      final danach = await b.container.read(
        eigeneEintraegeProvider(heute).future,
      );
      expect(danach.map((e) => e.name), ['Nachgereicht']);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Der gerechnete Tag', () {
    test('zählt zusammen, was in der Datenbank steht', () async {
      final b = behaelter();
      final repo = b.container.read(ernaehrungRepositoryProvider);
      await repo.buche(eintrag(tag: heute, kcal: 400));
      await repo.buche(eintrag(tag: heute, kcal: 300, stundeUtc: 16));
      // Beide `AsyncNotifier` einmal durchlaufen lassen.
      await b.container.read(eigeneEintraegeProvider(heute).future);
      await b.container.read(fremdeMahlzeitenProvider(heute).future);

      final tag = b.container.read(ernaehrungsTagProvider(heute));
      expect(tag.tagesSchluessel, heute);
      expect(tag.istHeute, isTrue);
      expect((tag.gegessen as Bekannt<Naehrwerte>).wert.kcal, 700);
    });

    test(
      'solange gelesen wird, steht kein Leerstand da — nur noch kein Wert',
      () async {
        // Vor dem ersten Durchlauf stehen beide `AsyncNotifier` auf
        // `AsyncLoading`. Der Schirm darf daraus keinen Grund machen.
        final b = behaelter(
          fremde: const NochNie<List<FremdeMahlzeit>>(),
          tageswerte: const NochNie<List<DailyMetrics>>(),
        );
        final tag = b.container.read(ernaehrungsTagProvider(heute));

        expect(tag.gegessen, isA<NochNie<Naehrwerte>>());
        expect(tag.zielLaedt, isTrue);
        expect(
          tag.bilanz.status,
          isNot(Zielstatus.keinZiel),
          reason:
              'der Grund „kein Ziel berechenbar" gehört zu einem FERTIGEN '
              'Lauf, nicht zu einem laufenden (Fehler `01`)',
        );
      },
    );

    test('wird gehalten, nicht bei jedem Zugriff gerechnet', () async {
      // Hausregel 2 aus `CLAUDE.md`: Was ein Provider einer Ansicht
      // anbietet, wird gehalten. Zwei Lesevorgänge ohne Änderung dazwischen
      // müssen **dasselbe Objekt** liefern — eine je Zugriff gerechnete
      // Eigenschaft gäbe zwei.
      final b = behaelter();
      await b.container.read(eigeneEintraegeProvider(heute).future);
      await b.container.read(fremdeMahlzeitenProvider(heute).future);

      final erst = b.container.read(ernaehrungsTagProvider(heute));
      final zweit = b.container.read(ernaehrungsTagProvider(heute));
      expect(identical(erst, zweit), isTrue);
    });

    test('jeder Tag rechnet für sich', () async {
      final b = behaelter();
      final repo = b.container.read(ernaehrungRepositoryProvider);
      await repo.buche(eintrag(tag: heute, kcal: 400));
      await b.container.read(eigeneEintraegeProvider(heute).future);
      await b.container.read(eigeneEintraegeProvider(gestern).future);
      await b.container.read(fremdeMahlzeitenProvider(heute).future);
      await b.container.read(fremdeMahlzeitenProvider(gestern).future);

      expect(
        (b.container.read(ernaehrungsTagProvider(heute)).gegessen
                as Bekannt<Naehrwerte>)
            .wert
            .kcal,
        400,
      );
      expect(
        (b.container.read(ernaehrungsTagProvider(gestern)).gegessen
                as Bekannt<Naehrwerte>)
            .wert
            .kcal,
        0,
      );
      expect(
        b.container.read(ernaehrungsTagProvider(gestern)).istHeute,
        isFalse,
      );
    });
  });
}

/// Steuerbare Ableger der echten Notifier — siehe `erholung_view_test.dart`:
/// Riverpods Provider-Typen sind invariant, ein eigenständiger
/// `AsyncNotifier` erfüllt die `overrideWith`-Signatur nicht.
class _Tageswerte extends DailyMetricsNotifier {
  _Tageswerte(this.wert);

  final Messwert<List<DailyMetrics>> wert;

  @override
  Future<Messwert<List<DailyMetrics>>> build() async => wert;
}

class _Stammdaten extends StammdatenNotifier {
  _Stammdaten(this.wert);

  final Stammdaten wert;

  @override
  Future<Stammdaten> build() async => wert;
}

class _Fremde extends FremdeMahlzeitenNotifier {
  _Fremde(this.wert) : super('');

  final Messwert<List<FremdeMahlzeit>> wert;

  @override
  Future<Messwert<List<FremdeMahlzeit>>> build() async => wert;
}
