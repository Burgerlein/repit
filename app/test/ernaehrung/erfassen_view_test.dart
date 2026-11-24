import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/data/lebensmittel_repository.dart';
import 'package:repit/ernaehrung/anlegen_blatt.dart';
import 'package:repit/ernaehrung/buchungs_blatt.dart';
import 'package:repit/ernaehrung/erfassen_formular.dart';
import 'package:repit/ernaehrung/erfassen_provider.dart';
import 'package:repit/ernaehrung/suche_view.dart';
import 'package:repit/health/health_provider.dart';

import '../design/support.dart' show textOf;

/// Tests für die **drei Oberflächen** des Eintragwegs (#285,
/// zugeschnitten): den Suchschirm und die beiden Blätter.
///
/// Die Rechnung darunter prüft `erfassen_formular_test.dart`, die
/// Verdrahtung `erfassen_rundweg_test.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, aber nicht verändert
/// werden.
///
/// ## Was diese Tests verbindlich vorgeben
///
/// ```dart
/// // lib/ernaehrung/suche_view.dart
/// /// Der Suchschirm (`erfassen.js`, Zustände `suche-leer` und
/// /// `suche-treffer`). Bringt **keinen** eigenen
/// /// `CupertinoPageScaffold` mit — den stellt, wer ihn schiebt.
/// class SucheView extends ConsumerWidget {
///   const SucheView({super.key, this.onGewaehlt});
///   /// Was passiert, wenn eine Trefferzeile angetippt wird.
///   final void Function(LebensmittelVorlage vorlage)? onGewaehlt;
/// }
///
/// // lib/ernaehrung/anlegen_blatt.dart
/// /// Das Blatt „Lebensmittel anlegen" (`erfassen.js`, Zustand
/// /// `anlegen`).
/// class AnlegenBlatt extends ConsumerStatefulWidget {
///   const AnlegenBlatt({super.key, this.onFertig});
///   /// Gerufen nach dem Sichern, mit dem Schlüssel des neuen
///   /// Lebensmittels.
///   final void Function(int id)? onFertig;
/// }
///
/// // lib/ernaehrung/buchungs_blatt.dart
/// /// Das Buchungsblatt (`erfassen.js`, Zustände `produkt` und
/// /// `aendern`) — **ein** Blatt für beides.
/// class BuchungsBlatt extends ConsumerStatefulWidget {
///   const BuchungsBlatt({super.key, required this.formular, this.onFertig});
///   final BuchungsFormular formular;
///   final VoidCallback? onFertig;
/// }
/// ```
///
/// ## Entscheidung des Test-Agenten: die Blätter schließen sich nicht selbst
///
/// **Nicht mit Tim abgestimmt, nicht freigegeben** — mit Begründung. Wer
/// ein Blatt öffnet, schließt es; das Blatt meldet nur, dass es fertig
/// ist. Ein Blatt, das selbst `Navigator.pop` ruft, ließe sich ohne
/// vorgeschobene Route nicht prüfen und hinge an der Art, wie es gezeigt
/// wird (Blatt, Seite, eingebettet). Die Rückmeldung ist derselbe Schnitt,
/// den `onWeg` in `ernaehrung_abschnitte.dart` schon benutzt.
///
/// ## Die Schlüssel
///
/// Weil es für „dieser Abschnitt ist da / ist nicht da" sonst keine
/// strukturelle Stelle im Baum gibt (dieselbe Begründung wie in
/// `ernaehrung_view_test.dart`):
///
/// - `Key('erfassen-suchfeld')` — das Suchfeld
/// - `Key('erfassen-liste')` — die Liste, in beiden Zuständen dieselbe
/// - `Key('erfassen-treffer-<id>')` — eine Zeile, `<id>` ist der
///   Lebensmittelschlüssel
/// - `Key('erfassen-leer')` — der Leerstand, **nur** wenn nachgesehen
///   wurde und nichts da ist
/// - `Key('erfassen-anlegen')` — der Weg „Lebensmittel anlegen"
/// - `Key('anlegen-name')`, `Key('anlegen-kcal')`, `Key('anlegen-eiweiss')`,
///   `Key('anlegen-zucker')` — Eingabefelder
/// - `Key('anlegen-sichern')` — der Knopf
/// - `Key('buchung-menge')` — das Mengenfeld
/// - `Key('buchung-naehrwerte')` — der Block mit den gerechneten Werten
/// - `Key('buchung-sichern')` — Buchen bzw. Sichern
/// - `Key('buchung-loeschen')` — **nur** beim Ändern
///
/// ## Was hier geprüft wird — und was nicht
///
/// `CLAUDE.md`: Widget-Tests prüfen **Zustände und Übergänge**, nicht
/// Layout und Beschriftung. Kein Fall hier nagelt eine Knopfbeschriftung,
/// eine Farbe oder einen Abstand fest. Die beiden Zustände, auf die es
/// ankommt, sind dieselben wie überall: Während des Lesens steht nie ein
/// „keine Daten"-Grund (Fehler `01`), und eine Anzeige, die es gibt,
/// verschwindet nicht, weil ihr Wert fehlt.
///
/// **Die Keine-Daten-Ansicht gehört dazu** (Tim, 28.10.2026) — ein Schirm
/// ohne sie ist nicht fertig. Für den Suchschirm heißt das: Ohne Eingabe
/// steht „zuletzt benutzt" da, und ist die eigene Tabelle noch leer, steht
/// der Grund da **und** der Weg hinaus.
///
/// ## Nachtrag #345: „Zuletzt benutzt" heißt gebucht
///
/// **Tims Entscheidung vom 04.11.2026:** Ohne Suchtext stehen nur
/// Lebensmittel da, die schon gebucht wurden, höchstens 10. Noch nichts
/// gebucht ist ein eigener Zustand mit `Key('zuletzt-leer')`
/// (`zuletzt_benutzt_test.dart`). **Geändert vom Test-Agenten von #345,
/// nicht vom Implementierenden; Tim hat die Änderung an dieser Datei
/// nicht gesehen.** Die Fälle unten, die ein bloß angelegtes Lebensmittel
/// ohne Suchtext erwarteten, buchen es jetzt vorher ([benutze]) oder
/// suchen danach; der Leerstand ohne Suchtext ist seitdem
/// `zuletzt-leer`, nicht mehr `erfassen-leer`.
///
/// Zahlen und Namen in dieser Datei sind erfunden.
void main() {
  // Dienstag, 14.07.2026, 12:00 Berliner Zeit (MESZ, +2).
  final jetzt = DateTime.utc(2026, 7, 14, 10);
  const heute = '2026-07-14';

  const haferflocken = Naehrwerte.je100g(
    kcal: 372,
    eiweissG: 13.5,
    kohlenhydrateG: 58.7,
    fettG: 7,
  );

  /// [trefferHaengen] hängt den Suchtreffer-Notifier an einem nie
  /// fertigen `Future` auf — die einzige zuverlässige Art, den
  /// Ladezustand festzuhalten. (`Override` ist in Riverpod 3 nicht
  /// exportiert, deshalb ein Schalter statt einer Übergabeliste.)
  ({ProviderContainer container, AppCache db}) behaelter({
    bool trefferHaengen = false,
  }) {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);

    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        if (trefferHaengen) suchtrefferProvider.overrideWith(_NieFertig.new),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, db: db);
  }

  Future<void> zeige(
    WidgetTester tester,
    ProviderContainer container,
    Widget inhalt, {
    bool warten = true,
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(home: CupertinoPageScaffold(child: inhalt)),
      ),
    );
    if (warten) await tester.pumpAndSettle();
  }

  String alleTexte(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map(textOf)
      .join(' ')
      .toLowerCase();

  String textUnter(WidgetTester tester, Key key) => tester
      .widgetList<Text>(
        find.descendant(of: find.byKey(key), matching: find.byType(Text)),
      )
      .map(textOf)
      .join(' ');

  bool gesperrt(WidgetTester tester, Key key) =>
      tester.widget<CupertinoButton>(find.byKey(key)).onPressed == null;

  Future<int> lege(
    ProviderContainer container,
    String name, {
    Naehrwerte je100g = haferflocken,
  }) => container
      .read(erfassenProvider.notifier)
      .legeLebensmittelAn(LebensmittelVorlage(name: name, je100g: je100g));

  /// Merkt die Benutzung, als wäre gebucht worden, und lässt die Suche
  /// nachlesen — seit #345 steht ohne Suchtext nur Gebuchtes da.
  Future<void> benutze(ProviderContainer container, int id) async {
    await container
        .read(lebensmittelRepositoryProvider)
        .merkeBenutzung(id, jetzt);
    await container.read(suchtrefferProvider.notifier).neuLesen();
  }

  // ═════════════════════════════════════════════════════════════════════
  group('Der Suchschirm', () {
    testWidgets('zeigt ohne Eingabe die zuletzt benutzten, keine leere Seite', (
      tester,
    ) async {
      final b = behaelter();
      final id = await lege(b.container, 'Haferflocken kernig');
      final nie = await lege(b.container, 'Skyr Natur');
      await benutze(b.container, id);
      await zeige(tester, b.container, const SucheView());

      expect(find.byKey(Key('erfassen-treffer-$id')), findsOneWidget);
      expect(
        find.byKey(Key('erfassen-treffer-$nie')),
        findsNothing,
        reason: '#345: angelegt ist nicht gebucht',
      );
      expect(find.byKey(const Key('erfassen-leer')), findsNothing);
      expect(find.byKey(const Key('zuletzt-leer')), findsNothing);
    });

    testWidgets('filtert, sobald etwas im Suchfeld steht', (tester) async {
      final b = behaelter();
      final hafer = await lege(b.container, 'Haferflocken kernig');
      final skyr = await lege(b.container, 'Skyr Natur');
      await zeige(tester, b.container, const SucheView());

      await tester.enterText(
        find.byKey(const Key('erfassen-suchfeld')),
        'Skyr',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(Key('erfassen-treffer-$skyr')), findsOneWidget);
      expect(find.byKey(Key('erfassen-treffer-$hafer')), findsNothing);
    });

    testWidgets('zeigt bei leerer Tabelle den Grund — und den Weg hinaus', (
      tester,
    ) async {
      final b = behaelter();
      await zeige(tester, b.container, const SucheView());

      // #345: Ohne Suchtext ist der Grund „noch nichts gebucht".
      expect(find.byKey(const Key('zuletzt-leer')), findsOneWidget);
      // Die Keine-Daten-Ansicht nimmt den Weg nicht mit: „Lebensmittel
      // anlegen" ist genau das, was hier zu tun ist.
      expect(find.byKey(const Key('erfassen-anlegen')), findsOneWidget);
    });

    // #345: Bis dahin prüfte dieser Fall, dass der Grund ohne Suchtext
    // weder Barcode noch Open Food Facts noch Scannen nennt — beides waren
    // damals spätere Tickets. Barcode (#324) und Open Food Facts (#284)
    // sind inzwischen gebaut, und der Entwurf des neuen Leerzustands
    // (`erfassen.js`, `ZULETZT_LEER`) verweist ausdrücklich aufs Scannen.
    // Geblieben ist, was der Fall außerdem sagte: Es steht ein Satz da,
    // nicht nichts — und keiner, der das noch nicht gebaute Foto zusagt.
    testWidgets('der Grund ist ein Satz und sagt kein Foto zu', (tester) async {
      final b = behaelter();
      await zeige(tester, b.container, const SucheView());

      final grund = textUnter(tester, const Key('zuletzt-leer')).toLowerCase();
      expect(grund, isNot(contains('foto')));
      expect(grund, isNotEmpty);
    });

    testWidgets('während gelesen wird, steht kein Leerstand da (Fehler 01)', (
      tester,
    ) async {
      final b = behaelter(trefferHaengen: true);
      await zeige(tester, b.container, const SucheView(), warten: false);
      await tester.pump();

      expect(find.byKey(const Key('erfassen-leer')), findsNothing);
      expect(alleTexte(tester), isNot(contains('noch keine')));
    });

    testWidgets('der Weg „Lebensmittel anlegen" steht auch neben Treffern da', (
      tester,
    ) async {
      final b = behaelter();
      final id = await lege(b.container, 'Haferflocken kernig');
      await benutze(b.container, id);
      await zeige(tester, b.container, const SucheView());

      expect(find.byKey(Key('erfassen-treffer-$id')), findsOneWidget);
      expect(find.byKey(const Key('erfassen-anlegen')), findsOneWidget);
    });

    testWidgets('eine Trefferzeile meldet die gewählte Vorlage', (
      tester,
    ) async {
      final b = behaelter();
      final id = await lege(b.container, 'Haferflocken kernig');
      await benutze(b.container, id);
      LebensmittelVorlage? gewaehlt;
      await zeige(
        tester,
        b.container,
        SucheView(onGewaehlt: (v) => gewaehlt = v),
      );

      await tester.tap(find.byKey(Key('erfassen-treffer-$id')));
      await tester.pumpAndSettle();

      expect(gewaehlt, isNotNull);
      expect(gewaehlt!.id, id);
      expect(gewaehlt!.je100g.kcal, 372);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Das Blatt „Lebensmittel anlegen"', () {
    testWidgets('„Sichern" ist gesperrt, solange Name oder Kalorien fehlen', (
      tester,
    ) async {
      final b = behaelter();
      await zeige(tester, b.container, const AnlegenBlatt());

      expect(gesperrt(tester, const Key('anlegen-sichern')), isTrue);

      await tester.enterText(find.byKey(const Key('anlegen-name')), 'Hafer');
      await tester.pumpAndSettle();
      expect(gesperrt(tester, const Key('anlegen-sichern')), isTrue);

      await tester.enterText(find.byKey(const Key('anlegen-kcal')), '372');
      await tester.pumpAndSettle();
      expect(gesperrt(tester, const Key('anlegen-sichern')), isFalse);
    });

    testWidgets('ein unlesbares freiwilliges Feld sperrt wieder zu', (
      tester,
    ) async {
      final b = behaelter();
      await zeige(tester, b.container, const AnlegenBlatt());

      await tester.enterText(find.byKey(const Key('anlegen-name')), 'Hafer');
      await tester.enterText(find.byKey(const Key('anlegen-kcal')), '372');
      await tester.pumpAndSettle();
      expect(gesperrt(tester, const Key('anlegen-sichern')), isFalse);

      await tester.enterText(
        find.byKey(const Key('anlegen-zucker')),
        'ein bisschen',
      );
      await tester.pumpAndSettle();
      expect(gesperrt(tester, const Key('anlegen-sichern')), isTrue);
    });

    testWidgets('Komma und Punkt öffnen gleichermaßen', (tester) async {
      final b = behaelter();
      await zeige(tester, b.container, const AnlegenBlatt());
      await tester.enterText(find.byKey(const Key('anlegen-name')), 'Hafer');

      await tester.enterText(find.byKey(const Key('anlegen-kcal')), '372,5');
      await tester.pumpAndSettle();
      expect(gesperrt(tester, const Key('anlegen-sichern')), isFalse);

      await tester.enterText(find.byKey(const Key('anlegen-kcal')), '372.5');
      await tester.pumpAndSettle();
      expect(gesperrt(tester, const Key('anlegen-sichern')), isFalse);
    });

    testWidgets('Sichern legt an — und das Lebensmittel steht sofort in der '
        'Suche', (tester) async {
      final b = behaelter();
      int? gemeldet;
      await zeige(
        tester,
        b.container,
        AnlegenBlatt(onFertig: (id) => gemeldet = id),
      );

      await tester.enterText(
        find.byKey(const Key('anlegen-name')),
        'Haferflocken kernig',
      );
      await tester.enterText(find.byKey(const Key('anlegen-kcal')), '372');
      await tester.enterText(find.byKey(const Key('anlegen-eiweiss')), '13,5');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('anlegen-sichern')));
      await tester.pumpAndSettle();

      expect(gemeldet, isNotNull);

      // Derselbe Behälter, neuer Schirm: kein Neustart, kein zweites
      // Lesen von Hand. #345: Angelegt ist nicht gebucht — ohne Suchtext
      // stünde es nicht da, deshalb wird danach gesucht (ein Buchstabe;
      // die Online-Suche beginnt erst bei zwei und ist hier nicht
      // Gegenstand).
      await zeige(tester, b.container, const SucheView());
      await tester.enterText(find.byKey(const Key('erfassen-suchfeld')), 'H');
      await tester.pumpAndSettle();
      expect(find.byKey(Key('erfassen-treffer-$gemeldet')), findsOneWidget);

      final vorlage = await b.container
          .read(lebensmittelRepositoryProvider)
          .lies(gemeldet!);
      expect(vorlage!.name, 'Haferflocken kernig');
      expect(vorlage.je100g.kcal, 372);
      expect(vorlage.je100g.eiweissG, 13.5);
      // Was nicht eingetippt wurde, ist nicht 0.
      expect(vorlage.je100g.fettG, isNull);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Das Buchungsblatt', () {
    BuchungsFormular neu() => BuchungsFormular.neu(
      vorlage: const LebensmittelVorlage(
        id: 42,
        name: 'Haferflocken kernig',
        je100g: haferflocken,
      ),
      tagesSchluessel: heute,
      jetzt: jetzt,
    );

    testWidgets('rechnet die Nährwerte aus der Menge', (tester) async {
      final b = behaelter();
      await zeige(tester, b.container, BuchungsBlatt(formular: neu()));

      await tester.enterText(find.byKey(const Key('buchung-menge')), '250');
      await tester.pumpAndSettle();

      expect(
        textUnter(tester, const Key('buchung-naehrwerte')),
        contains('930'),
      );
    });

    testWidgets('„Buchen" ist gesperrt ohne lesbare Menge', (tester) async {
      final b = behaelter();
      await zeige(tester, b.container, BuchungsBlatt(formular: neu()));

      await tester.enterText(find.byKey(const Key('buchung-menge')), '');
      await tester.pumpAndSettle();
      expect(gesperrt(tester, const Key('buchung-sichern')), isTrue);

      await tester.enterText(find.byKey(const Key('buchung-menge')), '0');
      await tester.pumpAndSettle();
      expect(gesperrt(tester, const Key('buchung-sichern')), isTrue);

      await tester.enterText(find.byKey(const Key('buchung-menge')), '250');
      await tester.pumpAndSettle();
      expect(gesperrt(tester, const Key('buchung-sichern')), isFalse);
    });

    testWidgets('der Nährwertblock steht auch ohne lesbare Menge da — '
        'ungefüllt', (tester) async {
      // „Eine Anzeige, die es gibt, hat genau eine Form": Sie verschwindet
      // nicht, weil ihr Wert fehlt — sonst springt das Blatt bei jedem
      // Tastendruck.
      final b = behaelter();
      await zeige(tester, b.container, BuchungsBlatt(formular: neu()));

      await tester.enterText(find.byKey(const Key('buchung-menge')), '');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('buchung-naehrwerte')), findsOneWidget);
      expect(
        textUnter(tester, const Key('buchung-naehrwerte')),
        isNot(contains('930')),
      );
    });

    testWidgets('ein neues Blatt trägt kein „Löschen", ein änderndes schon', (
      tester,
    ) async {
      final b = behaelter();
      await zeige(tester, b.container, BuchungsBlatt(formular: neu()));
      expect(find.byKey(const Key('buchung-loeschen')), findsNothing);

      await zeige(
        tester,
        b.container,
        BuchungsBlatt(
          formular: BuchungsFormular.fuer(
            Eintrag(
              id: 7,
              tagesSchluessel: heute,
              mahlzeit: Mahlzeit.abend,
              zeitpunkt: DateTime.utc(2026, 7, 14, 17),
              lebensmittelId: 42,
              name: 'Haferflocken kernig',
              mengeG: 250,
              naehrwerte: haferflocken.fuerMenge(250),
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('buchung-loeschen')), findsOneWidget);
    });

    testWidgets('Buchen schreibt und meldet sich fertig', (tester) async {
      final b = behaelter();
      var fertig = false;
      await zeige(
        tester,
        b.container,
        BuchungsBlatt(formular: neu(), onFertig: () => fertig = true),
      );

      await tester.enterText(find.byKey(const Key('buchung-menge')), '250');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('buchung-sichern')));
      await tester.pumpAndSettle();

      expect(fertig, isTrue);
      final eintraege = await b.container
          .read(ernaehrungRepositoryProvider)
          .eintraegeAmTag(heute);
      expect(eintraege.single.mengeG, 250);
      expect(eintraege.single.naehrwerte.kcal, closeTo(930, 1e-9));
    });
  });
}

/// Ein Suchtreffer-Notifier, der nie fertig wird — die einzige
/// zuverlässige Art, den Ladezustand festzuhalten. Ein `pump` ohne
/// `pumpAndSettle` wäre davon abhängig, wie viele Mikrotasks die
/// Datenbankabfrage braucht, und das ist keine Eigenschaft des Schirms.
class _NieFertig extends SuchtrefferNotifier {
  @override
  Future<List<LebensmittelVorlage>> build() =>
      Completer<List<LebensmittelVorlage>>().future;
}
